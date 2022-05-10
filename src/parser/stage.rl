INCLUDE "../src/file.rl"
INCLUDE "../ast/symbol.rl"
INCLUDE "../ast/global.rl"
INCLUDE "parser.rl"
INCLUDE "include.rl"
INCLUDE "global.rl"

::rlc::parser
{
	Config
	{
		TYPE Previous := Parser \;
		TYPE PrevExpression := :nothing;

		Registry: ast::[Config]FileRegistry;

		{}: Registry(&THIS);

		TYPE Symbol := Config-ast::Symbol;
		TYPE String := src::String;
		TYPE CharLiteral := tok::Token;
		TYPE StringLiteral := tok::Token - std::Vec;
		TYPE Name := src::String;
		TYPE ControlLabelName := tok::Token;
		TYPE Number := tok::Token;

		TYPE Inheritance := Symbol;
		TYPE MemberReference := Symbol::Child;
		TYPE MemberVariableReference := src::String;

		TYPE Includes := Include - std::Vec;

		transform_includes(
			out: Includes&,
			p: Parser \
		) VOID
		{
			i: parser::Include;
			WHILE(i.parse(*p))
				out += &&i;
		}

		transform_globals(
			out: ast::[Config]Global-std::DynVec&,
			p: Parser \
		) VOID
		{
			WHILE(glob ::= global::parse(*p))
				out += &&glob;

			IF(!p->eof())
			{
				p->fail("expected scope entry");
				DIE;
			}
		}

		create_file(
			file: std::str::CV#&
		) Config-ast::File \
		{
			s: src::File-std::Shared := :new(file);
			p: Parser(s!);
			= std::heap::[Config-ast::File]new(:transform(:nothing, &p));
		}
	}
}