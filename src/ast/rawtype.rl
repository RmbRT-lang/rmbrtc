INCLUDE "scopeitem.rl"
INCLUDE "global.rl"
INCLUDE "member.rl"
INCLUDE "expression.rl"
INCLUDE "../src/file.rl"

INCLUDE 'std/memory'
INCLUDE 'std/vector'

::rlc::ast [Stage:TYPE] Rawtype VIRTUAL -> [Stage]ScopeItem, CodeObject
{
	Size: [Stage]Expression-std::Dyn;
	Alignment: [Stage]Expression-std::Dyn;
	Members: [Stage]Member - std::DynVec;

	:transform{
		p: [Stage::Prev+]Rawtype #&,
		f: Stage #&
	} -> (:transform(p, f)), (p):
		Size := <<<[Stage]Expression>>>(p.Size!, f),
		Members := :reserve(##p.Members)
	{
		IF(p.Alignment)
			Alignment := <<<[Stage]Expression>>>(p.Alignment!, f);
		FOR(it ::= p.Members.start(); it; ++it)
			Members += <<<[Stage]Member>>>(it!, f);
	}
}

::rlc::ast [Stage:TYPE] GlobalRawtype -> [Stage]Global, [Stage]Rawtype
{
	:transform{
		p: [Stage::Prev+]GlobalRawtype #&,
		f: Stage #&
	} -> (), (:transform(p, f));
}

::rlc::ast [Stage:TYPE] MemberRawtype -> [Stage]Member, [Stage]Rawtype
{
	:transform{
		p: [Stage::Prev+]MemberRawtype #&,
		f: Stage #&
	} -> (p), (:transform(p, f));
}