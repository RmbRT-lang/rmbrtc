INCLUDE "statement.rl"

::rlc::ast [Stage: TYPE] Destructor -> [Stage]Member
{
	Body: [Stage]BlockStatement;
	Inline: BOOL;

	:transform{
		p: [Stage::Prev+]Destructor #&,
		f: Stage::PrevFile+,
		s: Stage &
	} -> (:transform, p):
		Body := :transform(p.Body, f, s),
		Inline := p.Inline;
}