INCLUDE "typeorexpression.rl"

INCLUDE "../src/file.rl"

INCLUDE 'std/vector'

::rlc::ast
{
	[Stage: TYPE] TYPE TemplateArg := [Stage]TypeOrExpr - std::DynVec;

	[Stage: TYPE] Symbol
	{
		Child
		{
			Name: Stage::Name;
			Templates: Stage-TemplateArg-std::Vec;
			Position: src::Position;
		}

		Children: Child - std::Vec;
		IsRoot: BOOL;
	}
}