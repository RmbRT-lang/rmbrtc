INCLUDE "../ast/extern.rl"
INCLUDE "parser.rl"
INCLUDE "variable.rl"
INCLUDE "function.rl"
INCLUDE "stage.rl"

::rlc::parser::extern parse(p: Parser &) ast::[Config]Global - std::Dyn
{
	IF(!p.consume(:extern))
		= NULL;

	t: Trace(&p, "external symbol");
	IF(p.match_ahead(:colon))
	{
		IF:!(var ::= variable::parse_extern(p))
			p.fail("expected variable");
		= &&var;
	} ELSE
	{
		IF:!(f ::= function::parse_extern(p))
			p.fail("expected function");
		= &&f;
	}
}