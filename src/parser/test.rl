INCLUDE "../ast/test.rl"
INCLUDE "parser.rl"
INCLUDE "stage.rl"

::rlc::parser::test parse(p: Parser &, out: ast::[Config]Test &) BOOL
{
	IF:!(tok ::= p.consume(:test))
		= FALSE;
	out.Position := tok->Position;

	t: Trace(&p, "test");

	out.Name := p.expect(:stringQuote).Content;

	IF(!statement::parse_block(p, out.Body))
		p.fail("expected block statement");

	= TRUE;
}