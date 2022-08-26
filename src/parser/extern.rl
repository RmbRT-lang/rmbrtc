INCLUDE "../ast/extern.rl"
INCLUDE "parser.rl"
INCLUDE "variable.rl"
INCLUDE "function.rl"
INCLUDE "stage.rl"

::rlc::parser::extern parse(p: Parser &) ast::[Config]Global - std::Dyn
{
	IF(!p.consume(:extern))
		= NULL;

	linkName: Config::StringLiteral - std::Opt;
	IF(p.consume(:bracketOpen))
		linkName := :a(:vec(p.expect(:stringQuote)));

	t: Trace(&p, "external symbol");
	IF(p.match_ahead(:colon))
	{
		IF:!(var ::= variable::parse_extern(p, &&linkName))
			p.fail("expected variable");
		= :dup(&&*var);
	} ELSE
	{
		IF:!(f ::= function::help::parse_extern(p, &&linkName))
			p.fail("expected function");
		= &&f;
	}
}