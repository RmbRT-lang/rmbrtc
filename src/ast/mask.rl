INCLUDE "global.rl"
INCLUDE "member.rl"
INCLUDE "function.rl"
INCLUDE "templatedecl.rl"
INCLUDE "scopeitem.rl"
INCLUDE "global.rl"
INCLUDE "member.rl"

INCLUDE 'std/vector'
INCLUDE 'std/memory'

::rlc::ast [Stage:TYPE] Mask VIRTUAL -> [Stage]ScopeItem
{
	Members: Member - std::DynVector;
}

::rlc::parser GlobalMask -> Global, Mask
{
}