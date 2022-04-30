INCLUDE "stage.rl"
INCLUDE "../ast/destructor.rl"

::rlc::parser::destructor parse(p: Parser&, out: ast::[Stage]Destructor &) BOOL
{
	IF(!p.consume(:destructor))
		= FALSE;

	out.Inline := p.consume(:inline);

	IF(!statement::parse_block(p, out.Body))
		p.fail("expected block statement");

	= TRUE;
}