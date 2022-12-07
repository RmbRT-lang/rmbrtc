INCLUDE "scopeitem.rl"
INCLUDE "global.rl"
INCLUDE "member.rl"

::rlc::ast [Stage:TYPE] Union VIRTUAL -> [Stage]ScopeItem, [Stage]ScopeBase
{
	Members: [Stage]Fields;

	:transform{
		p: [Stage::Prev+]Union #&,
		f: Stage::PrevFile+,
		s: Stage &,
		parent: [Stage]ScopeBase \
	} -> (:transform, p, f, s), (:childOf, parent):
		Members := :transform(p.Members, f, s, &THIS);
}

::rlc::ast [Stage:TYPE] GlobalUnion -> [Stage]Global, [Stage]Union {
	:transform{
		p: [Stage::Prev+]GlobalUnion #&,
		f: Stage::PrevFile+,
		s: Stage &,
		parent: [Stage]ScopeBase \
	} -> (), (:transform, p, f, s, parent);
}

::rlc::ast [Stage:TYPE] MemberUnion -> [Stage]Member, [Stage]Union {
	:transform{
		p: [Stage::Prev+]MemberUnion #&,
		f: Stage::PrevFile+,
		s: Stage &,
		parent: [Stage]ScopeBase \
	} -> (:transform, p), (:transform, p, f, s, parent);
}