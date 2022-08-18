INCLUDE "global.rl"
INCLUDE "scopeitem.rl"
INCLUDE "statement.rl"
INCLUDE "codeobject.rl"

::rlc::ast [Stage:TYPE] Test -> [Stage]Global, CodeObject
{
	Name: Stage::String;
	Body: [Stage]BlockStatement;

	:transform{
		p: [Stage::Prev+]Test #&,
		f: Stage::PrevFile+,
		s: Stage &
	} -> (), (p):
		Name := s.transform_name(p.Name, f),
		Body := :transform(p.Body, f, s);
}