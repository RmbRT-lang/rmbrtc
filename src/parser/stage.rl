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
		TYPE Context := Parser \;

		TYPE Symbol := Config-ast::Symbol;
		TYPE String := src::String;
		TYPE Name := src::String;
		TYPE Inheritance := Symbol;
		MemberReference { Member: src::String; Position: src::Position; }

		TYPE Includes := Include - std::Vector;

		STATIC transform_includes(:nothing, p: Parser \) Includes
		{
			ret: Includes;

			i: parser::Include;
			WHILE(i.parse(*p))
				ret += &&i;

			= &&ret;
		}

		STATIC transform_globals(:nothing, p: Parser \) ast::[Config]Global - std::DynVector
		{
			ret: ast::[Config]Global - std::DynVector;

			WHILE(glob ::= global::parse(p))
				ret += &&glob;

			IF(!p.eof())
				p.fail("expected scope entry");

			= &&glob;
		}
	}
}