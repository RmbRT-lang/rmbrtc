INCLUDE "global.rl"
INCLUDE "member.rl"
INCLUDE "function.rl"
INCLUDE "templatedecl.rl"
INCLUDE "scopeitem.rl"
INCLUDE "global.rl"
INCLUDE "member.rl"

INCLUDE 'std/vector'
INCLUDE 'std/memory'

::rlc::ast [Stage:TYPE] Mask VIRTUAL ->
	[Stage]ScopeItem,
	[Stage]Templateable,
	CodeObject
{
	Members: [Stage]Member - std::DynVec;

	:transform{
		p: [Stage::Prev+]Mask #&,
		f: Stage::PrevFile+,
		s: Stage &
	} -> (:transform, p, f, s), (:transform, p, f, s), (p):
		Members := :reserve(##p.Members)
	{
		FOR(m ::= p.Members.start())
			Members += <<<[Stage]Member>>>(m!, f, s);
	}
}

::rlc::ast [Stage:TYPE] GlobalMask -> [Stage]Global, [Stage]Mask
{
	:transform{
		p: [Stage::Prev+]GlobalMask #&,
		f: Stage::PrevFile+,
		s: Stage &
	} -> (), (:transform, p, f, s);
}