INCLUDE "parser.rl"
INCLUDE "../ast/controllabel.rl"
INCLUDE "stage.rl"

::rlc::parser::control_label parse(
	p: Parser &
) ast::[Config]ControlLabel - std::Opt
{
	IF(p.consume(:bracketOpen))
	{
		IF(!p.match(:stringBacktick)
		&& !p.match(:stringQuote))
			p.fail("expected \"\" or `` string");

		t ::= p.eat_token()!.Content;
		p.expect(:bracketClose);
		= :a(&&t);
	}
}