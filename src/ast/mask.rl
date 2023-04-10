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
	[Stage]CoreType,
	[Stage]Instantiable
{
	Members: [Stage]Member - std::DynVec;

	:transform{
		p: [Stage::Prev+]Mask #&,
		ctx: Stage::Context+ #&
	} -> (:transform, p, ctx), (:transform, p, ctx), (), (:childOf, ctx.ParentInst!):
		Members := :reserve(##p.Members)
	{
		_ctx ::= ctx.in_parent(&p.Templates, &THIS.Templates).in_path(&THIS);
		FOR(m ::= p.Members.start())
			Members += <<<[Stage]Member>>>(m!, _ctx);
	}
}

::rlc::ast [Stage:TYPE] GlobalMask -> [Stage]Global, [Stage]Mask
{
	:transform{
		p: [Stage::Prev+]GlobalMask #&,
		ctx: Stage::Context+ #&
	} -> (), (:transform, p, ctx);
}