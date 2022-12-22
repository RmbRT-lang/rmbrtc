INCLUDE "scopeitem.rl"
INCLUDE "global.rl"
INCLUDE "member.rl"

::rlc::ast [Stage:TYPE] Union VIRTUAL ->
	[Stage]ScopeItem,
	[Stage]CoreType
{
	Members: [Stage]Fields;

	:transform{
		p: [Stage::Prev+]Union #&,
		ctx: Stage::Context+ #&
	} -> (:transform, p, ctx), ():
		Members := :transform(p.Members, ctx);
}

::rlc::ast [Stage:TYPE] GlobalUnion -> [Stage]Global, [Stage]Union {
	:transform{
		p: [Stage::Prev+]GlobalUnion #&,
		ctx: Stage::Context+ #&
	} -> (), (:transform, p, ctx);
}

::rlc::ast [Stage:TYPE] MemberUnion -> [Stage]Member, [Stage]Union {
	:transform{
		p: [Stage::Prev+]MemberUnion #&,
		ctx: Stage::Context+ #&
	} -> (:transform, p), (:transform, p, ctx);
}