INCLUDE "scopeitem.rl"
INCLUDE "global.rl"

INCLUDE 'std/set'

::rlc::ast [Stage:TYPE] Namespace -> [Stage]MergeableScopeItem, [Stage]Global
{
	Entries: [Stage]Global - std::DynVector;
}