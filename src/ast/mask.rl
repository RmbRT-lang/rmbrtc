INCLUDE "global.rl"
INCLUDE "member.rl"
INCLUDE "function.rl"
INCLUDE "templatedecl.rl"
INCLUDE "scopeitem.rl"
INCLUDE "global.rl"
INCLUDE "member.rl"

INCLUDE 'std/vector'
INCLUDE 'std/memory'

::rlc::ast [Stage:TYPE] Mask VIRTUAL ->
	[Stage]ScopeItem,
	[Stage]Templateable,
	CodeObject
{
	Members: [Stage]Member - std::DynVec;
}

::rlc::ast [Stage:TYPE] GlobalMask -> [Stage]Global, [Stage]Mask
{
}