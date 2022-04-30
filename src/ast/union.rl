INCLUDE "scopeitem.rl"
INCLUDE "global.rl"
INCLUDE "member.rl"

::rlc::ast [Stage:TYPE] Union VIRTUAL -> [Stage]ScopeItem
{
	Members: Member - std::DynVector;
}

::rlc::ast GlobalUnion -> Global, Union { }

::rlc::ast MemberUnion -> Member, Union { }