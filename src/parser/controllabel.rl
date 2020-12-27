INCLUDE "parser.rl"
INCLUDE "../src/file.rl"
INCLUDE "../tokeniser/token.rl"

::rlc::parser ControlLabel
{
	{}:
		Exists(FALSE);

	Exists: bool;
	(// Identifier or string. /)
	Name: tok::Token;

	parse(p: Parser &) VOID
	{
		IF(Exists := p.consume(:bracketOpen))
		{
			IF(!p.consume(:stringBacktick, &Name)
			&& !p.consume(:stringQuote, &Name))
				p.fail("expected \"\" or `` string");
			p.expect(:bracketClose);
		}
	}
}