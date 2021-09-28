INCLUDE "expression.rl"
INCLUDE "type.rl"

INCLUDE "../util/dynunion.rl"

::rlc::resolver
{
	TemplateArg VIRTUAL
	{
		<<<
			scope: scoper::Scope #\,
			args: scoper::TypeOrExpr# - std::Buffer #&
		>>> TemplateArg \
		{
			ASSERT(##args);
			IF(args.front().is_type())
				RETURN std::[TemplateTypesArg]new(args, scope);
			ELSE
				RETURN std::[TemplateValuesArg]new(args, scope);
		}
	}
	TYPE TemplateArgs := TemplateArg-std::DynVector;

	TemplateTypesArg -> TemplateArg
	{
		Types: resolver::Type - std::DynVector;

		{
			types: scoper::TypeOrExpr# - std::Buffer #&,
			scope: scoper::Scope #\
		}
		{
			FOR(it ::= types.start(); it; ++it)
				Types += :gc(<<<resolver::Type>>>(scope, it!.type()));
		}
	}

	TemplateValuesArg -> TemplateArg
	{
		Values: Expression - std::DynVector;

		{
			values: scoper::TypeOrExpr# - std::Buffer #&,
			scope: scoper::Scope #\
		}
		{
			FOR(it ::= values.start(); it; ++it)
				Values += :gc(<<<Expression>>>(scope, it!.expression()));
		}
	}
}