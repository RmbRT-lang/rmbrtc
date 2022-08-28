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
			s: Stage &
		} -> (:transform, p, f, s), (:transform, p, f, s):
			Type := <<<ast::[Stage]Type>>>(p.Type!, f, s);
	}

	[Stage:TYPE] GlobalTypedef -> [Stage]Global, [Stage]Typedef
	{
		:transform{
			p: [Stage::Prev+]GlobalTypedef #&,
			f: Stage::PrevFile+,
			s: Stage &
		} -> (), (:transform, p, f, s);
	}

	[Stage:TYPE] MemberTypedef -> [Stage]Member, [Stage]Typedef
	{
		:transform{
			p: [Stage::Prev+]MemberTypedef #&,
			f: Stage::PrevFile+,
			s: Stage &
		} -> (:transform, p), (:transform, p, f, s);
	}
}