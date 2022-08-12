INCLUDE "scopeitem.rl"
INCLUDE "global.rl"
INCLUDE "member.rl"

::rlc::ast [Stage:TYPE] Union VIRTUAL -> [Stage]ScopeItem, CodeObject
{
	Members: [Stage]Member - std::DynVec;

	:transform{
		p: [Stage::Prev+]Union #&,
		f: Stage #&
	} -> (:transform(p, f)), (p):
		Members := :reserve(##p.Members)
	{
		FOR(it ::= p.Members.start(); it; ++it)
			Members += <<<[Stage]Member>>>(it!, f);
	}
}

::rlc::ast [Stage:TYPE] GlobalUnion -> [Stage]Global, [Stage]Union {
	:transform{
		p: [Stage::Prev+]GlobalUnion #&,
		f: Stage #&
	} -> (), (:transform(p, f));
}

::rlc::ast [Stage:TYPE] MemberUnion -> [Stage]Member, [Stage]Union {
	:transform{
		p: [Stage::Prev+]MemberUnion #&,
		f: Stage #&
	} -> (p), (:transform(p, f));
}