INCLUDE "type.rl"
INCLUDE "scopeitem.rl"
INCLUDE "global.rl"
INCLUDE "member.rl"
INCLUDE "templateable.rl"

::rlc::ast
{
	[Stage:TYPE] Typedef VIRTUAL -> [Stage]ScopeItem, [Stage]Templateable
	{
		Type: ast::[Stage]Type-std::Dyn;

		:transform{
			p: [Stage::Prev+]Typedef #&,
			f: Stage::PrevFile+,
			s: Stage &,
			parent: [Stage]ScopeBase \
		} -> (:transform, p, f, s), (:transform, p, f, s, parent):
			Type := :make(p.Type!, f, s, parent);
	}

	[Stage:TYPE] GlobalTypedef -> [Stage]Global, [Stage]Typedef
	{
		:transform{
			p: [Stage::Prev+]GlobalTypedef #&,
			f: Stage::PrevFile+,
			s: Stage &,
			parent: [Stage]ScopeBase \
		} -> (), (:transform, p, f, s, parent);
	}

	[Stage:TYPE] MemberTypedef -> [Stage]Member, [Stage]Typedef
	{
		:transform{
			p: [Stage::Prev+]MemberTypedef #&,
			f: Stage::PrevFile+,
			s: Stage &,
			parent: [Stage]ScopeBase \
		} -> (:transform, p), (:transform, p, f, s, parent);
	}
}