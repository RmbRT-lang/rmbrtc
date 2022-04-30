INCLUDE "scopeitem.rl"
INCLUDE "global.rl"
INCLUDE "member.rl"

::rlc::ast [Stage:TYPE] Union VIRTUAL -> [Stage]ScopeItem
{
	Members: [Stage]Member - std::DynVec;
}

::rlc::ast [Stage:TYPE] GlobalUnion -> [Stage]Global, [Stage]Union { }

::rlc::ast [Stage:TYPE] MemberUnion -> [Stage]Member, [Stage]Union { }