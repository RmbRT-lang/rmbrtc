INCLUDE "global.rl"
INCLUDE "member.rl"
INCLUDE "function.rl"
INCLUDE "templatedecl.rl"
INCLUDE "scopeitem.rl"
INCLUDE "global.rl"
INCLUDE "member.rl"

INCLUDE 'std/vector'
INCLUDE 'std/memory'

::rlc::ast [Stage:TYPE] Mask VIRTUAL -> [Stage]ScopeItem, [Stage]Templateable
{
	Members: [Stage]Member - std::DynVec;

	:transform{
		p: [Stage::Prev+]Mask #&,
		ctx: Stage::Context+ #&
	} -> (:transform, p, ctx), (:transform, p, ctx):
		Members := :reserve(##p.Members)
	{
		FOR(m ::= p.Members.start())
			Members += <<<[Stage]Member>>>(m!, ctx);
	}
}

::rlc::ast [Stage:TYPE] GlobalMask -> [Stage]Global, [Stage]Mask
{
	:transform{
		p: [Stage::Prev+]GlobalMask #&,
		ctx: Stage::Context+ #&
	} -> (), (:transform, p, ctx);
}