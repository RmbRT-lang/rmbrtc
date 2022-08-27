INCLUDE "parser.rl"
INCLUDE "../ast/controllabel.rl"
INCLUDE "stage.rl"

::rlc::parser::control_label parse(
	p: Parser &
) ast::[Config]ControlLabel - std::Opt
{
	IF(!p.consume(:bracketOpen))
		= NULL;

	IF(!p.match(:stringBacktick)
	&& !p.match(:stringQuote)
	&& !p.match(:identifier))
		p.fail("expected identifier, \"\" or `` string");

	label: ast::[Config]ControlLabel (BARE);
	tok ::= p.eat_token()!;
	(label.Name, label.Position) := (tok, tok.Position);
	p.expect(:bracketClose);
	= :a(&&label);
}