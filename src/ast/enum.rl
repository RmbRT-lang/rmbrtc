INCLUDE "scopeitem.rl"
INCLUDE "../src/file.rl"

INCLUDE 'std/vector'

::rlc::ast [Stage: TYPE] Enum VIRTUAL -> [Stage]ScopeItem, CodeObject
{
	Constant -> [Stage]ScopeItem, [Stage]Member, CodeObject
	{
		Value: src::Index;
	}

	Constants: std::[Constant]Vec;
}

::rlc::ast [Stage: TYPE] GlobalEnum -> [Stage]Global, [Stage]Enum
{
}

::rlc::ast [Stage: TYPE] MemberEnum -> [Stage]Member, [Stage]Enum
{
}