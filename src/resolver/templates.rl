INCLUDE "expression.rl"
INCLUDE "type.rl"

INCLUDE "../util/dynunion.rl"

::rlc::resolver
{
	TemplateArg VIRTUAL
	{
		ENUM Type { types, values }
		# ABSTRACT type() Type;

		STATIC create(
			scope: scoper::Scope #\,
			args: scoper::TypeOrExpr - std::Vector #&) TemplateArg \
		{
			ASSERT(!args.empty());
			IF(args.front().is_type())
				RETURN std::[TemplateTypesArg]new(args, scope);
			ELSE
				RETURN std::[TemplateValuesArg]new(args, scope);
		}
	}
	TYPE TemplateArgs := TemplateArg-std::DynVector;

	TemplateTypesArg -> TemplateArg
	{
		# FINAL type() TemplateArg::Type := :types;

		Types: resolver::Type - std::DynVector;

		{
			types: scoper::TypeOrExpr - std::Vector #&,
			scope: scoper::Scope #\
		}
		{
			FOR(it ::= types.start(); it; ++it)
				Types += :gc(resolver::Type::create(scope, it->type()));
		}
	}

	TemplateValuesArg -> TemplateArg
	{
		# FINAL type() TemplateArg::Type := :values;

		Values: Expression - std::DynVector;

		{
			values: scoper::TypeOrExpr - std::Vector #&,
			scope: scoper::Scope #\
		}
		{
			FOR(it ::= values.start(); it; ++it)
				Values += :gc(Expression::create(scope, it->expression()));
		}
	}
}