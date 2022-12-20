INCLUDE "../parser/stage.rl"
INCLUDE "../util/file.rl"
INCLUDE "../ast/test.rl"
INCLUDE "includes.rl"
INCLUDE "../ast/scopeitem.rl"
INCLUDE "../ast/cache.rl"
INCLUDE "../ast/stage.rl"
INCLUDE "../ast/symbol.rl"

INCLUDE 'std/dyn'
INCLUDE 'std/unicode'



::rlc::scoper Config
{
	ParsedRegistry: ast::[parser::Config]FileRegistry \;
	Registry: ast::[THIS]FileRegistry;
	IncludeDirs: std::Str - std::Buffer;
	DummyScope: ast::[parser::Config]GlobalScope;

	TYPE Prev := parser::Config;
	TYPE PrevFile := ast::[Prev]File #\;

	TYPE Context := scoper::Context;

	Includes
	{
		From: ast::[Config]File \ -std::VecSet;
		FromMissing: std::Str -std::VecSet;

		Into: ast::[Config]File \ -std::VecSet;
	}

	TYPE Name := std::str::CV;
	TYPE String := std::str::CV;
	TYPE Symbol := ast::[THIS]Symbol;
	TYPE MemberReference := ast::[THIS]Symbol::Child;
	TYPE Inheritance := THIS-ast::Symbol;

	Number
	{
		Sign: BOOL;
		Value: U8;

		{...};
		:nat{v: U8}: Sign := FALSE, Value := v;
		:int{v: S8}: Sign := v < 0, Value := v < 0 ?? -v : v;
	}

	TYPE CharLiteral := U4;
	TYPE StringLiteral := std::Str;
	TYPE ControlLabelName := Name;
	TYPE ControlLabelReference := ControlLabelName;
	TYPE MemberVariableReference := Name;
	
	RootScope
	{
		ScopeItems: ast::[Config]GlobalScope;
		Tests: ast::[Config]Test - std::Vec;

		{}: ScopeItems := :root;
	}

	Globals: RootScope-std::Shared;

	{prev: parser::Config \, includes: std::Str - std::Buffer}:
		ParsedRegistry(&prev->Registry),
		Registry(&THIS),
		IncludeDirs(includes),
		Globals := :a(),
		DummyScope := :root;

	transform() VOID
	{
		FOR(f ::= ParsedRegistry->start())
			Registry.get(f!.Source->Name);
	}

	transform_includes(
		out: Includes&,
		file: ast::[THIS]File *,
		parsed: ast::[parser::Config]File #\
	) VOID
	{
		FOR(inc ::= parsed->Includes.start())
		{
			path: std::Str := include::resolve(
				parsed->name(),
				inc!,
				*parsed->Source,
				IncludeDirs);

			TRY
			{
				from ::= Registry.get(path);
				out.From += from;
				from->Includes.Into += file;
				IF(from->Includes.FromMissing -= parsed->name())
					from->Includes.From += file;
			}
			CATCH(:loading) out.FromMissing += &&path;
		}
	}

	transform_globals(
		out: RootScope&,
		p: ast::[parser::Config]File #\
	) VOID
	{
		ctx ::= <Context>(p, &THIS).in_parent(&DummyScope, &out.ScopeItems);
		FOR(g ::= p->Globals->start())
			IF(s ::= <<parser::Config-ast::ScopeItem #*>>(*g))
				out.ScopeItems.insert_or_merge(s->Name, *s, ctx);
			ELSE
			{
				test:?&:= <<parser::Config-ast::Test #&>>(g!);
				out.Tests += :transform(test, ctx);
			}
	}

	create_file(file: std::str::CV#&) THIS-ast::File - std::Dyn
		:= :a(:transform_with_scope(ParsedRegistry->get(file), THIS, Globals));
}

::rlc::scoper Context -> ast::[Config]DefaultContext
{
	TYPE Prev := parser::Config;

	PrevFile: ast::[Prev]File #\;
	Stage: Config \;

	{
		p: ast::[Prev]File #\,
		s: Config \
	} -> ():
		PrevFile := p,
		Stage := s;

	# visit_scope_item(_, _) VOID INLINE {}

	# transform_name(
		p: Prev::Name+ #&
	) Config::Name INLINE
		:= PrevFile->Source->content(p)++;

	# transform_control_label_name(
		p: Prev::ControlLabelName #&
	) Config::ControlLabelName
		:= PrevFile->Source->content(p.Content)++;

	# transform_control_label_reference(
		p: Prev::ControlLabelReference - std::Opt #&,
		_
	) Config::ControlLabelReference -std::Opt
	{
		IF(p)
			= :a(<Config::ControlLabelReference>(PrevFile->Source->content(p!.Content)++));
		= NULL;
	}

	# transform_member_reference(
		p: Prev::MemberReference+ #&
	) Config::MemberReference INLINE
		:= :transform(p, THIS);
	
	# transform_member_variable_reference(
		p: Prev::MemberVariableReference+ #&
	) Config::MemberVariableReference INLINE
		:= transform_name(p);
	
	# transform_inheritance(
		p: Prev::Inheritance+ #&
	) Config::Inheritance
		:= :transform(p, THIS);

	# transform_number(p: Prev::Number+ #&) Config::Number INLINE
	{
		ASSERT(p.Type == :numberLiteral);
		num: std::str::CV := PrevFile->Source->content(p.Content)++;

		acc: U8;
		IF(num.starts_with("0x") || num.starts_with("0X"))
			FOR(c ::= num.start()+<UM>(2))
			{
				digit: U1 (NOINIT);
				SWITCH(c!)
				{
				'a', 'b', 'c', 'd', 'e', 'f': digit := c! - ('a' - 0xa);
				'A', 'B', 'C', 'D', 'E', 'F': digit := c! - ('A' - 0xa);
				DEFAULT: digit := c! - '0';
				}
				acc := acc << 4 | digit;
			}
		ELSE FOR(c ::= num.start())
			acc := 10 * acc + (c! - '0');

		= :nat(acc);
	}

	# transform_char_literal(p: Prev::CharLiteral+ #&) Config::CharLiteral
	{
		src ::= PrevFile->Source->content(p.Content);

		points: std::[U4]Vec := :reserve(##src);
		FOR(c ::= src.start(); c;)
		{
			len ::= std::code::utf8::size(c!);
			ASSERT(c + (len-1));
			points += std::code::utf8::point(&*c);
			c := c + len;
		}

		content_points ::= points!.drop_start(1).drop_end(1);
		p ::= content_points.start();
		= parse_char(p);
	}

	# transform_string(p: parser::Config::String) Config::String
		:= PrevFile->Source->content(p)++;

	# transform_string_literal(p: tok::Token-std::Buffer #&) Config::StringLiteral
	{
		str: Config::StringLiteral;
		FOR(token ::= p.start())
		{
			src ::= PrevFile->Source->content(token!.Content);

			points: std::[U4]Vec := :reserve(##src);
			FOR(c ::= src.start(); c;)
			{
				len ::= std::code::utf8::size(c!);
				ASSERT(c + (len-1));
				points += std::code::utf8::point(&*c);
				c := c + len;
			}

			content_points ::= points!.drop_start(1).drop_end(1);
			transformed: std::[U4]Vec := :reserve(##points-2);
			FOR(p ::= content_points.start())
				transformed += parse_char(p);

			enc: CHAR[4];
			encoded: CHAR-std::Vec := :reserve(##transformed);
			FOR(t ::= transformed.start())
			{
				l ::= std::code::utf8::encode(t!, &enc[0]);
				FOR(i ::= 0; i < l; i++)
					encoded += enc[i];
			}

			str += <std::str::CV>(encoded!++);
		}

		= &&str;
	}

	STATIC parse_char(p: std::[U4, std::[U4]Buffer]Iterator &) U4
	{
		IF(p! != '\\')
			= p!;
		ELSE SWITCH(c ::= *++p)
		{
		'\\': = '\\';
		'"': = '"';
		'\'': = '\'';
		'n': = '\n';
		't': = '\t';
		'e': = '\e';
		'r': = '\r';
		'z': = 0;
		'0', '1', '2', '3': // octal u8 point
		{
			n: U4 := c;
			FOR(i ::= 0; i < 2; i++)
				SWITCH(c := *++p)
				{
				'0', '1', '2', '3', '4', '5', '6', '7':
					n := 8 * n + c;
				}

			= n;
		}
		'x', 'u', 'U': // u8, u16, u32 hex point
		{
			n: U4 := 0;

			l: U1;
			SWITCH(c) { 'x': l := 2; 'u': l := 4; 'U': l := 8; }

			FOR(i ::= 0; i < l; i++)
			{
				d: U1;
				SWITCH(c := *++p)
				{
				'0', '1', '2', '3', '4', '5', '6', '7', '8', '9':
					d := c - '0';
				'a', 'b', 'c', 'd', 'e', 'f':
					d := c - 'a';
				'A', 'B', 'C', 'D', 'E', 'F':
					d := c - 'A';
				}
				n := (n << 4) | d;
			}

			= n;
		}
		}
	}

	# transform_symbol(
		p: Prev::Symbol #&, _
	) Config::Symbol := :transform(p, THIS);
}