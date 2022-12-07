INCLUDE "stage.rl"
INCLUDE "../ast/destructor.rl"

::rlc::parser::destructor parse(p: Parser&, out: ast::[Config]Destructor &) BOOL
{
	IF:!(t ::= p.consume(:destructor))
		= FALSE;
	out.Position := t!.Position;
	out.Inline := p.consume(:inline);

	locals: ast::LocalPosition;
	IF(!statement::parse_block(p, locals, out.Body))
		p.fail("expected block statement");

	= TRUE;
}