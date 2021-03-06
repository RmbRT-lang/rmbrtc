INCLUDE "../parser/type.rl"

INCLUDE "expression.rl"
INCLUDE "symbol.rl"

::rlc::scoper
{
	TYPE TypeType := parser::TypeType;

	Type VIRTUAL
	{
		# ABSTRACT type() TypeType;

		TYPE ReferenceType := parser::Type::ReferenceType;
		TYPE Indirection := parser::Type::Indirection;
		Qualifier
		{
			Const: BOOL;
			Volatile: BOOL;
			{}: Const(FALSE), Volatile(FALSE);
			{c: BOOL, v: BOOL}: Const(c), Volatile(v);
			{
				cpy: parser::Type::Qualifier#&
			}:	Const(cpy.Const),
				Volatile(cpy.Volatile);
		}

		Modifier
		{
			Indirection: Type::Indirection;
			Qualifier: Type::Qualifier;
			IsArray: BOOL;
			ArraySize: Expression - std::DynVector;

			{
				parsed: parser::Type::Modifier#&,
				file: src::File#&
			}:	Indirection(parsed.Indirection),
				Qualifier(parsed.Qualifier),
				IsArray(parsed.IsArray)
			{
				FOR(i ::= 0; i < ##parsed.ArraySize; i++)
					ArraySize += :gc(Expression::create(parsed.ArraySize[i], file));
			}
		}

		Auto
		{
			Qualifier: Type::Qualifier;
			Reference: Type::ReferenceType;

			{}: Reference(ReferenceType::none);
			{a: parser::Type::Auto#&}:
				Qualifier(a.Qualifier.Const, a.Qualifier.Volatile),
				Reference(a.Reference);

		}

		Modifiers: std::[Modifier]Vector;
		Reference: Type::ReferenceType;
		Variadic: BOOL;

		PROTECTED {
			parsed: parser::Type #\,
			file: src::File#&}:
			Reference(parsed->Reference),
			Variadic(parsed->Variadic)
		{
			FOR(i ::= 0; i < ##parsed->Modifiers; i++)
				Modifiers += (parsed->Modifiers[i], file);
		}

		STATIC create(
			parsed: parser::Type #\,
			file: src::File#&
		) Type \ := detail::create_type(parsed, file);
	}
}