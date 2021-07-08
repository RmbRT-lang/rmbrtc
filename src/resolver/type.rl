INCLUDE "../scoper/type.rl"

INCLUDE "expression.rl"

::rlc::resolver Type VIRTUAL
{
	ENUM Kind
	{
		reference,
		signature,
		void,
		null,
		symbolConstant,
		tuple,
		expression,
		builtin
	}

	# ABSTRACT type() Kind;

	TYPE ReferenceType := scoper::Type::ReferenceType;
	TYPE Indirection := scoper::Type::Indirection;
	TYPE Qualifier := scoper::Type::Qualifier;
	TYPE Auto := scoper::Type::Auto;

	# plain() BOOL := Reference == :none && !Modifiers;

	Modifier
	{
		Indirection: Type::Indirection;
		Qualifier: Type::Qualifier;
		IsArray: BOOL;
		ArraySize: Expression - std::Dynamic - std::Vector;

		{
			scoped: scoper::Type::Modifier#&,
			scope: scoper::Scope #\
		}:	Indirection(scoped.Indirection),
			Qualifier(scoped.Qualifier),
			IsArray(scoped.IsArray)
		{
			FOR(i ::= 0; i < ##scoped.ArraySize; i++)
				ArraySize += :gc(Expression::create(scope, scoped.ArraySize[i]));
		}
	}

	Modifiers: Modifier - std::Vector;
	Reference: Type::ReferenceType;
	Variadic: BOOL;

	PROTECTED {
		scoped: scoper::Type #\,
		scope: scoper::Scope #\
	}:	Reference(scoped->Reference),
		Variadic(scoped->Variadic)
	{
		FOR(i ::= 0; i < ##scoped->Modifiers; i++)
			Modifiers += (scoped->Modifiers[i], scope);
	}

	STATIC create(
		scope: scoper::Scope #\,
		scopedType: scoper::Type #\
	) Type \ := detail::create_type(scope, scopedType);
}