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
	TYPE Number := Prev::Number+;
	TYPE CharLiteral := U4;
	TYPE StringLiteral := std::Str;
	TYPE ControlLabelName := std::Str;
	
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

	transform_string(p: Prev::String+ #&, f: PrevFile) String
	{
		src ::= f->Source->content(p);

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
			IF(p! != '\\')
				transformed += p!;
			ELSE
			{
				SWITCH(c ::= *++p)
				{
				'\\': transformed += '\\';
				'"': transformed += '"';
				'\'': transformed += '\'';
				'n': transformed += '\n';
				't': transformed += '\t';
				'e': transformed += '\e';
				'z': transformed += 0;
				'0', '1', '2', '3': // octal u8 point
				{
					n: U4 := c;
					FOR(i ::= 0; i < 2; i++)
						SWITCH(c := *++p)
						{
						'0', '1', '2', '3', '4', '5', '6', '7':
							n := 8 * n + c;
						}

					transformed += n;
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
				}
				}
			}


		enc: CHAR[4];
		encoded: CHAR-std::Vec := :reserve(##transformed);
		FOR(t ::= transformed.start())
		{
			l ::= std::code::utf8::encode(t!, &enc[0]);
			FOR(i ::= 0; i < l; i++)
				encoded += enc[i];
		}

		= <std::str::CV>(encoded!++);
	}

	transform_includes(
		out: Includes&,
		parsed: ast::[parser::Config]File #\
	) VOID
	{
		FOR(inc ::= parsed->Includes.start())
			out += Registry.get(
				include::resolve(
					parsed->Name!,
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