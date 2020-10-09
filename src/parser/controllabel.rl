INCLUDE "parser.rl"
INCLUDE "../src/file.rl"
INCLUDE "../tokeniser/token.rl"

::rlc::parser ControlLabel
{
	CONSTRUCTOR():
		Exists(FALSE);

	Exists: bool;
	(// Identifier or string. /)
	Name: tok::Token;

	parse(p: Parser &) VOID
	{
		IF(Exists := p.consume(tok::Type::bracketOpen))
		{
			IF(!p.consume(tok::Type::stringBacktick, &Name)
			&& !p.consume(tok::Type::stringQuote, &Name))
				p.fail("expected \"\" or `` string");
			p.expect(tok::Type::bracketClose);
		}
	}
}