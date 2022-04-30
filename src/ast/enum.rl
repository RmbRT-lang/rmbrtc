INCLUDE "scopeitem.rl"
INCLUDE "../src/file.rl"

INCLUDE 'std/vector'

::rlc::parser [Stage: TYPE] Enum VIRTUAL -> [Stage]ScopeItem, CodeObject
{
	Constant -> [Stage]ScopeItem, [Stage]Member, CodeObject
	{
		Value: src::Index;
	}

	Constants: std::[Constant]Vector;
}

::rlc::parser [Stage: TYPE] GlobalEnum -> [Stage]Global, [Stage]Enum
{
}

::rlc::parser [Stage: TYPE] MemberEnum -> [Stage]Member, [Stage]Enum
{
}