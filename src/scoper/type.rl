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
			Const: bool;
			Volatile: bool;
			CONSTRUCTOR(): Const(FALSE), Volatile(FALSE);
			CONSTRUCTOR(c: bool, v: bool): Const(c), Volatile(v);
			CONSTRUCTOR(
				cpy: parser::Type::Qualifier#&
			):	Const(cpy.Const),
				Volatile(cpy.Volatile);
		}

		Modifier
		{
			Indirection: Type::Indirection;
			Qualifier: Type::Qualifier;
			IsArray: bool;
			ArraySize: std::[std::[Expression]Dynamic]Vector;

			CONSTRUCTOR(
				parsed: parser::Type::Modifier#&,
				file: src::File#&
			):	Indirection(parsed.Indirection),
				Qualifier(parsed.Qualifier),
				IsArray(parsed.IsArray)
			{
				FOR(i ::= 0; i < parsed.ArraySize.size(); i++)
					ArraySize.push_back(Expression::create(parsed.ArraySize[i], file));
			}
		}

		Auto
		{
			Qualifier: Type::Qualifier;
			Reference: Type::ReferenceType;

			CONSTRUCTOR(): Reference(ReferenceType::none);
			CONSTRUCTOR(a: parser::Type::Auto#&):
				Qualifier(a.Qualifier.Const, a.Qualifier.Volatile),
				Reference(a.Reference);

		}

		Modifiers: std::[Modifier]Vector;
		Reference: Type::ReferenceType;

		PROTECTED CONSTRUCTOR(
			parsed: parser::Type #\,
			file: src::File#&):
			Reference(parsed->Reference)
		{
			FOR(i ::= 0; i < parsed->Modifiers.size(); i++)
				Modifiers.emplace_back(parsed->Modifiers[i], file);
		}

		STATIC create(
			parsed: parser::Type #\,
			file: src::File#&
		) Type \ := detail::create_type(parsed, file);
	}
}