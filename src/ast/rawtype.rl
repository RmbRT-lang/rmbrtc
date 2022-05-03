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
}

::rlc::ast [Stage:TYPE] GlobalRawtype -> [Stage]Global, [Stage]Rawtype
{
}

::rlc::ast [Stage:TYPE] MemberRawtype -> [Stage]Member, [Stage]Rawtype
{
}