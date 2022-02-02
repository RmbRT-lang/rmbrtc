INCLUDE "expression.rl"
INCLUDE "type.rl"
INCLUDE "scopeitem.rl"
INCLUDE 'std/hash'

::rlc::instantiator
{
	TemplateArg VIRTUAL -> std::CustomHashable
	{
		<<<
			arg: resolver::TemplateArg #\,
			scope: Scope #&
		>>> TemplateArg \
		{
			ASSERT(arg);
			IF(type ::= <<resolver::TemplateTypesArg #*>>(arg))
				RETURN std::[TemplateTypesArg]new(type, scope);
			ELSE
				RETURN std::[TemplateValuesArg]new(
					<resolver::TemplateValuesArg #\>(arg),
					scope);
		}
	}

	TYPE TemplateArgs := TemplateArg-std::DynVector;

	TemplateTypesArg -> TemplateArg
	{
		Types: Type #\ - std::Vector;

		{
			types: resolver::TemplateTypesArg #\,
			scope: Scope #&
		}
		{
			FOR(it ::= types->Types!.start(); it; ++it)
				Types += <<<Type>>>(it!, scope);
		}

		# FINAL hash(h: std::Hasher &) VOID { h(Types); }
	}

	TemplateValuesArg -> TemplateArg
	{
		Values: Expression - std::DynVector;

		{
			values: resolver::TemplateValuesArg #\,
			scope: Scope #&
		}
		{
			FOR(it ::= values->Values!.start(); it; ++it)
				Values += :gc(<<<Expression>>>(it!, scope));
		}

		# FINAL hash(h: std::Hasher &) VOID { h(Values); }
	}
}