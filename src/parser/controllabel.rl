INCLUDE "parser.rl"
INCLUDE "../ast/controllabel.rl"
INCLUDE "stage.rl"

::rlc::parser::control_label parse_ref(
	p: Parser &
) tok::Token - std::Opt
{
	IF(!p.consume(:bracketOpen))
		= NULL;

	IF(!p.match(:stringBacktick)
	&& !p.match(:stringQuote)
	&& !p.match(:identifier))
		p.fail("expected identifier, \"\" or `` string");

	tok ::= p.eat_token()!;
	p.expect(:bracketClose);
	= :a(&&tok);
}

::rlc::parser::control_label parse(
	p: Parser &
) ast::[Config]ControlLabel -std::Opt
{
	IF(name ::= parse_ref(p))
	{
		label: ast::[Config]ControlLabel (BARE);
		(label.Name, label.Position) := (name!, name!.Position);
		= :a(&&label);
	}
	= NULL;
}