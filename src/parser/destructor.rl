INCLUDE "stage.rl"
INCLUDE "../ast/destructor.rl"

::rlc::parser::destructor parse(p: Parser&, out: ast::[Config]Destructor &) BOOL
{
	IF(!p.consume(:destructor))
		= FALSE;

	out.Inline := p.consume(:inline);

	locals: ast::LocalPosition;
	IF(!statement::parse_block(p, locals, out.Body))
		p.fail("expected block statement");

	= TRUE;
}