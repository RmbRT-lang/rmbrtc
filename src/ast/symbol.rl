INCLUDE "typeorexpression.rl"

INCLUDE "../src/file.rl"

INCLUDE 'std/vector'

::rlc::ast
{
	[Stage: TYPE] TYPE TemplateArg := [Stage]TypeOrExpr - std::DynVec;
	[Stage: TYPE] transform_template_args(
		prev: [Stage::Prev+]TemplateArg# - std::Buffer,
		ctx: Stage::Context+ #&
	) [Stage]TemplateArg - std::Vec
	{
		ret: [Stage]TemplateArg - std::Vec := :reserve(##prev);
		FOR(tpl ::= prev.start())
		{
			it:?& :=  ret += :reserve(##tpl!);
			FOR(v ::= tpl!.start())
				it += :make(v!, ctx);
		}
		= &&ret;
	}

	[Stage: TYPE] Symbol
	{
		Child
		{
			Name: Stage::Name;
			Templates: Stage-TemplateArg-std::Vec;
			Position: src::Position;

			:transform{
				prev: [Stage::Prev+]Symbol::Child #&,
				ctx: Stage::Context+ #&
			}:
				Name := ctx.transform_name(prev.Name),
				Position := prev.Position,
				Templates := 
					[Stage]transform_template_args(
						prev.Templates!++, ctx);
		}

		Children: Child - std::Vec;
		IsRoot: BOOL;

		:transform{
			prev: [Stage::Prev+]Symbol #&,
			ctx: Stage::Context+ #&
		}:
			Children := :reserve(##prev.Children),
			IsRoot := prev.IsRoot
		{
			FOR(c ::= prev.Children.start())
				Children += :transform(c!, ctx);
		}
	}
}