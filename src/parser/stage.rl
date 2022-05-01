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
		TYPE Previous := :nothing;
		TYPE PrevExpression := :nothing;
		TYPE Context := Parser \;

		TYPE Symbol := Config-ast::Symbol;
		TYPE String := src::String;
		TYPE CharLiteral := tok::Token;
		TYPE StringLiteral := tok::Token;
		TYPE Name := src::String;
		TYPE ControlLabelName := src::String;
		TYPE Number := tok::Token;

		TYPE Inheritance := Symbol;
		TYPE MemberReference := Symbol::Child;

		TYPE Includes := Include - std::Vec;

		STATIC transform_includes(:nothing, p: Parser \) Includes
		{
			ret: Includes;

			i: parser::Include;
			WHILE(i.parse(*p))
				ret += &&i;

			= &&ret;
		}

		STATIC transform_globals(:nothing, p: Parser \) ast::[Config]Global - std::DynVec
		{
			ret: ast::[Config]Global - std::DynVec;

			WHILE(glob ::= global::parse(p))
				ret += &&glob;

			IF(!p.eof())
				p.fail("expected scope entry");

			= &&glob;
		}
	}
}