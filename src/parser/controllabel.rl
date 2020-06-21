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
		Exists := p.consume(tok::Type::stringBacktick, &Name);
	}
}