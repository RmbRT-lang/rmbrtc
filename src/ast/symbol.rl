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

			:transform{
				prev: [Stage::Prev+]Symbol::Child #&,
				f: Stage::PrevFile+,
				s: Stage &,
				parent: [Stage]ScopeBase \
			}:
				Name := s.transform_name(prev.Name, f),
				Templates := :reserve(##prev.Templates),
				Position := prev.Position
			{
				FOR(pt ::= prev.Templates.start())
				{
					t:?&:= Templates += :reserve(##pt!);
					FOR(pa ::= pt!.start())
						IF(e ::= <<ast::[Stage::Prev+]Expression #*>>(&pa!))
							t += :<>(<<<ast::[Stage]Expression>>>(*e, f, s, parent));
						ELSE
							t += :<>(<<<ast::[Stage]Type>>>(>>pa!, f, s, parent));
				}
			}
		}

		Children: Child - std::Vec;
		IsRoot: BOOL;

		:transform{
			prev: [Stage::Prev+]Symbol #&,
			f: Stage::PrevFile+,
			s: Stage &,
			parent: [Stage]ScopeBase \
		}:
			Children := :reserve(##prev.Children),
			IsRoot := prev.IsRoot
		{
			FOR(c ::= prev.Children.start())
				Children += :transform(c!, f, s, parent);
		}
	}
}