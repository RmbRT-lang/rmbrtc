INCLUDE "../parser/stage.rl"
INCLUDE "../util/file.rl"
INCLUDE "../ast/test.rl"
INCLUDE "includes.rl"
INCLUDE "../ast/scopeitem.rl"
INCLUDE "../ast/cache.rl"

INCLUDE 'std/heaped'
INCLUDE 'std/unicode'

::rlc::scoper Config
{
	ParsedRegistry: ast::[parser::Config]FileRegistry \;
	Registry: ast::[THIS]FileRegistry;
	IncludeDirs: std::Str - std::Buffer;

	MSIs: ast::[THIS; ast::[THIS]MergeableScopeItem]Cache - std::Heaped;

	TYPE Prev := parser::Config;
	TYPE PrevFile := ast::[parser::Config]File #\;
	TYPE Context := Config \;
	TYPE Includes := Config-ast::File \-std::Vec;
	TYPE Name := std::str::CV;
	TYPE String := std::Str;
	TYPE Symbol := ast::[THIS]Symbol;
	TYPE MemberReference := Symbol::Child;
	TYPE Inheritance := THIS-ast::Symbol;

	Number
	{
		Sign: BOOL;
		Value: U8;

		{...};
		:nat{v: U8}: Sign := FALSE, Value := v;
		:int{v: S8}: Sign := v < 0, Value := v < 0 ? -v : v;
	}

	TYPE CharLiteral := U4;
	TYPE StringLiteral := std::Str;
	TYPE ControlLabelName := Name;
	TYPE MemberVariableReference := Name;
	
	RootScope
	{
		ScopeItems: std::[std::str::CV; ast::[Config]ScopeItem]AutoDynMap;
		Tests: ast::[Config]Test - std::Vec;
	}

	{prev: parser::Config \}:
		ParsedRegistry(&prev->Registry),
		Registry(&THIS);

	transform_name(p: Prev::Name+ #&, f: PrevFile) Name INLINE
		:= f->Source->content(p)++;
	transform_control_label_name(p: Prev::ControlLabelName #&, f: PrevFile) ControlLabelName := f->Source->content(p.Content)++;
	transform_member_reference(p: Prev::MemberReference+ #&, f: PrevFile) MemberReference INLINE
		:= :transform(p, f, THIS);
	transform_member_variable_reference(p: Prev::MemberVariableReference+ #&, f: PrevFile) MemberVariableReference INLINE
		:= transform_name(p, f);
	transform_inheritance(p: Prev::Inheritance+ #&, f: PrevFile) Inheritance := :transform(p, f, THIS);

	transform_number(p: Prev::Number+ #&, f: PrevFile) Number INLINE
	{
		ASSERT(p.Type == :numberLiteral);
		num: std::str::CV := f->Source->content(p.Content)++;

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

	transform_char_literal(p: Prev::CharLiteral+ #&, f: PrevFile) CharLiteral
	{
		src ::= f->Source->content(p.Content);

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

	transform_string_literal(p: tok::Token-std::Buffer #&, f: PrevFile) StringLiteral
	{
		str: StringLiteral;
		FOR(token ::= p.start())
		{
			src ::= f->Source->content(token!.Content);

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


	transform_symbol(
		p: Prev::Symbol #&,
		f: PrevFile
	) Symbol := :transform(p, f, THIS);

	transform_includes(
		out: Includes&,
		parsed: ast::[parser::Config]File #\
	) VOID
	{
		FOR(inc ::= parsed->Includes.start())
			out += Registry.get(
				include::resolve(
					parsed->Source->Name!,
					inc!,
					*parsed->Source,
					IncludeDirs));
	}

	transform_globals(
		out: RootScope&,
		p: ast::[parser::Config]File #\
	) VOID
	{
		FOR(g ::= p->Globals.start())
		{
			IF(s ::= <<parser::Config-ast::ScopeItem #\>>(g!))
			{
				conv ::= <<<Config-ast::ScopeItem>>>(s, p, THIS);
				out.ScopeItems.insert(conv->Name!, &&conv);
			} ELSE
			{
				test ::= <<parser::Config-ast::Test #\>>(g!);
				out.Tests += :transform(*test, p, THIS);
			}
		}
	}

	create_file(file: std::str::CV#&) THIS-ast::File - std::Dyn
		:= :a(:transform(ParsedRegistry->get(file), THIS));
}