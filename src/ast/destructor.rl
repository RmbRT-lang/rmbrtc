INCLUDE "statement.rl"

::rlc::ast [Stage: TYPE] Destructor -> [Stage]Member, CodeObject
{
	Body: [Stage]BlockStatement;
	Inline: BOOL;

	:transform{
		p: [Stage::Prev+]Destructor #&,
		f: Stage::PrevFile+,
		s: Stage &,
		parent: [Stage]ScopeBase \
	} -> (:transform, p), (p):
		Body := :transform(p.Body, f, s, parent),
		Inline := p.Inline;
}