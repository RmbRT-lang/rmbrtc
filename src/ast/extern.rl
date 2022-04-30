INCLUDE "scopeitem.rl"
INCLUDE "type.rl"
INCLUDE "../src/file.rl"

::rlc::ast [Stage: TYPE] ExternVariable -> [Stage]Global, [Stage]ScopeItem
{
	Type: [Stage]Type - std::Dyn;
}

::rlc::ast [Stage: TYPE] ExternFunction -> [Stage]Global, [Stage]ScopeItem
{
	Arguments: [Stage]Type - std::DynVec;
	Return: [Stage]Type - std::Dyn;
}