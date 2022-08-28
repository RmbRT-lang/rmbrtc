INCLUDE "scopeitem.rl"
INCLUDE "global.rl"
INCLUDE "member.rl"

::rlc::ast [Stage:TYPE] Union VIRTUAL -> [Stage]ScopeItem, CodeObject
{
	Members: [Stage]Member - std::DynVec;

	:transform{
		p: [Stage::Prev+]Union #&,
		f: Stage::PrevFile+,
		s: Stage &
	} -> (:transform, p, f, s), (p):
		Members := :reserve(##p.Members)
	{
		FOR(it ::= p.Members.start())
			Members += <<<[Stage]Member>>>(it!, f, s);
	}
}

::rlc::ast [Stage:TYPE] GlobalUnion -> [Stage]Global, [Stage]Union {
	:transform{
		p: [Stage::Prev+]GlobalUnion #&,
		f: Stage::PrevFile+,
		s: Stage &
	} -> (), (:transform, p, f, s);
}

::rlc::ast [Stage:TYPE] MemberUnion -> [Stage]Member, [Stage]Union {
	:transform{
		p: [Stage::Prev+]MemberUnion #&,
		f: Stage::PrevFile+,
		s: Stage &
	} -> (:transform, p), (:transform, p, f, s);
}