INCLUDE "statement.rl"

::rlc::ast [Stage: TYPE] Destructor -> [Stage]Member, CodeObject
{
	Body: [Stage]BlockStatement;
	Inline: BOOL;

	:transform{
		p: [Stage::Prev+]Destructor #&,
		ctx: Stage::Context+ #&
	} -> (:transform, p), (p):
		Body := :transform(p.Body, ctx),
		Inline := p.Inline;
}