INCLUDE "parser.rl"
INCLUDE "type.rl"
INCLUDE "../src/file.rl"

INCLUDE 'std/vector'

::rlc::parser
{
	TemplateArg
	{
		CONSTRUCTOR(move: TemplateArg&&):
			Type(__cpp_std::move(move.Type));

		Type: std::[parser::Type]Dynamic;
	}


	// std::[T]Vector
	Symbol
	{
		// [T]Vector
		Child
		{
			Name: src::String;
			Templates: std::[TemplateArg]Vector;

			parse(
				p: Parser &) bool
				:= p.consume(tok::Type::identifier, &Name);
		}

		Children: std::[Child]Vector;
		IsRoot: bool;

		parse(
			p: Parser &) bool
		{
			t: Trace(&p, "symbol");

			IsRoot := p.consume(tok::Type::doubleColon);
			expect ::= IsRoot;

			DO(child: Child)
			{
				IF(!child.parse(p))
				{
					IF(expect)
						p.fail();
					RETURN FALSE;
				}

				Children.push_back(__cpp_std::move(child));
			} WHILE(p.consume(tok::Type::doubleColon))

			RETURN TRUE;
		}
	}
}