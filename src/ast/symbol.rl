INCLUDE "typeorexpression.rl"

INCLUDE "../src/file.rl"

INCLUDE 'std/vector'

::rlc::ast
{
	[Stage: TYPE] TYPE TemplateArg := [Stage]TypeOrExpr - std::DynVector;

	[Stage: TYPE] Symbol
	{
		Child
		{
			Name: Stage::Name;
			Templates: Stage-TemplateArg-std::Vector;
			Position: src::Position;
		}

		Children: Child - std::Vector;
		IsRoot: BOOL;
	}
}