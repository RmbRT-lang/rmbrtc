INCLUDE "type.rl"
INCLUDE "scopeitem.rl"
INCLUDE "global.rl"
INCLUDE "member.rl"
INCLUDE "templateable.rl"
INCLUDE "scope.rl"

::rlc::ast
{
	[Stage:TYPE] Typedef VIRTUAL -> [Stage]ScopeItem, [Stage]Templateable, PotentialScope
	{
		Type: ast::[Stage]Type-std::Dyn;

		:transform{
			p: [Stage::Prev+]Typedef #&,
			ctx: Stage::Context+ #&
		} -> (:transform, p, ctx), (:transform, p, ctx), ():
			Type := :make(p.Type!, ctx);
	}

	[Stage:TYPE] GlobalTypedef -> [Stage]Global, [Stage]Typedef
	{
		:transform{
			p: [Stage::Prev+]GlobalTypedef #&,
			ctx: Stage::Context+ #&
		} -> (), (:transform, p, ctx);
	}

	[Stage:TYPE] MemberTypedef -> [Stage]Member, [Stage]Typedef
	{
		:transform{
			p: [Stage::Prev+]MemberTypedef #&,
			ctx: Stage::Context+ #&
		} -> (:transform, p), (:transform, p, ctx);
	}
}