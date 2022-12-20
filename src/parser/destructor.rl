INCLUDE "stage.rl"
INCLUDE "../ast/destructor.rl"

::rlc::parser::destructor parse(p: Parser&, out: ast::[Config]Destructor &) BOOL
{
	IF:!(t ::= p.consume(:destructor))
		= FALSE;
	out.Position := t!.Position;
	out.Inline := p.consume(:inline);

	IF(!statement::parse_block(p, out.Body))
		p.fail("expected block statement");

	= TRUE;
}