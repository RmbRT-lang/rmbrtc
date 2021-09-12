INCLUDE "../type.rl"
INCLUDE "../symbol.rl"

INCLUDE 'std/err/unimplemented'


::rlc::scoper::detail create_type(
	parsed: parser::Type #\,
	file: src::File#&
) Type \
{
	TYPE SWITCH(parsed)
	{
	DEFAULT:
		THROW <std::err::Unimplemented>(TYPE(parsed));
	CASE parser::Signature:
		RETURN std::[Signature]new(<parser::Signature #\>(parsed), file);
	CASE parser::SymbolConstantType:
		RETURN std::[SymbolConstantType]new(<parser::SymbolConstantType #\>(parsed), file);
	CASE parser::Void:
		RETURN std::[Void]new(<parser::Void #\>(parsed), file);
	CASE parser::Null:
		RETURN std::[Null]new(<parser::Null #\>(parsed), file);
	CASE parser::TypeName:
		RETURN std::[TypeName]new(<parser::TypeName #\>(parsed), file);
	CASE parser::TupleType:
		RETURN std::[TupleType]new(<parser::TupleType #\>(parsed), file);
	CASE parser::TypeOfExpression:
		RETURN std::[TypeOfExpression]new(<parser::TypeOfExpression #\>(parsed), file);
	CASE parser::BuiltinType:
		RETURN std::[BuiltinType]new(<parser::BuiltinType #\>(parsed), file);
	}
}

::rlc::scoper
{
	Signature -> Type
	{
		Arguments: Type - std::DynVector;
		Return: std::[Type]Dynamic;

		{
			parsed: parser::Signature #\,
			file: src::File #&
		}->	Type(parsed, file)
		:	Return(:gc, <<<Type>>>(parsed->Ret, file))
		{
			FOR(i ::= 0; i < ##parsed->Args; i++)
				Arguments += :gc(<<<Type>>>(parsed->Args[i], file));
		}
	}

	SymbolConstantType -> Type
	{
		Name: String;

		{
			parsed: parser::SymbolConstantType #\,
			file: src::File #&
		}->	Type(parsed, file)
		:	Name(file.content(parsed->Name));
	}

	Void -> Type
	{
		{
			parsed: parser::Void #\,
			file: src::File#&
		}->	Type(parsed, file);
	}

	Null -> Type
	{
		{
			parsed: parser::Null #\,
			file: src::File#&
		}->	Type(parsed, file);
	}

	TypeName -> Type
	{
		Name: Symbol;
		NoDecay: BOOL;

		{
			parsed: parser::TypeName #\,
			file: src::File#&
		}->	Type(parsed, file)
		:	Name(parsed->Name, file),
			NoDecay(parsed->NoDecay);
	}

	TupleType -> Type
	{
		Types: Type - std::DynVector;

		{
			parsed: parser::TupleType #\,
			file: src::File #&
		}->	Type(parsed, file)
		{
			FOR(i ::= 0; i < ##parsed->Types; i++)
				Types += :gc(<<<Type>>>(parsed->Types[i], file));
		}
	}

	TypeOfExpression -> Type
	{
		Expression: scoper::Expression - std::Dynamic;

		{
			parsed: parser::TypeOfExpression #\,
			file: src::File #&
		}->	Type(parsed, file)
		:	Expression(:gc, <<<scoper::Expression>>>(parsed->Expression, file));
	}

	BuiltinType -> Type
	{
		TYPE Primitive := parser::BuiltinType::Primitive;
		Kind: Primitive;

		{
			parsed: parser::BuiltinType #\,
			file: src::File#&
		}->	Type(parsed, file)
		:	Kind(parsed->Kind);
	}
}