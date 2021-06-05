INCLUDE "../type.rl"
INCLUDE "../symbol.rl"

INCLUDE 'std/err/unimplemented'


::rlc::scoper::detail create_type(
	parsed: parser::Type #\,
	file: src::File#&
) Type \
{
	SWITCH(type ::= parsed->type())
	{
	DEFAULT:
		THROW std::err::Unimplemented(type.NAME());
	CASE :signature:
		RETURN std::[Signature]new(<parser::Signature #\>(parsed), file);
	CASE :symbolConstant:
		RETURN std::[SymbolConstantType]new(<parser::SymbolConstantType #\>(parsed), file);
	CASE :void:
		RETURN std::[Void]new(<parser::Void #\>(parsed), file);
	CASE :name:
		RETURN std::[TypeName]new(<parser::TypeName #\>(parsed), file);
	CASE :tuple:
		RETURN std::[TupleType]new(<parser::TupleType #\>(parsed), file);
	CASE :expression:
		RETURN std::[TypeOfExpression]new(<parser::TypeOfExpression #\>(parsed), file);
	CASE :builtin:
		RETURN std::[BuiltinType]new(<parser::BuiltinType #\>(parsed), file);
	}
}

::rlc::scoper
{
	Signature -> Type
	{
		# FINAL type() TypeType := :signature;

		Arguments: std::[std::[Type]Dynamic]Vector;
		Return: std::[Type]Dynamic;

		{
			parsed: parser::Signature #\,
			file: src::File #&}:
			Type(parsed, file),
			Return(:gc, Type::create(parsed->Ret, file))
		{
			FOR(i ::= 0; i < ##parsed->Args; i++)
				Arguments += :gc(Type::create(parsed->Args[i], file));
		}
	}

	SymbolConstantType -> Type
	{
		# FINAL type() TypeType := :symbolConstant;

		Name: String;

		{
			parsed: parser::SymbolConstantType #\,
			file: src::File #&
		}:	Type(parsed, file),
			Name(file.content(parsed->Name));
	}

	Void -> Type
	{
		# FINAL type() TypeType := :void;

		{
			parsed: parser::Void #\,
			file: src::File#&}:
			Type(parsed, file);
	}

	TypeName -> Type
	{
		# FINAL type() TypeType := :name;

		Name: Symbol;
		NoDecay: BOOL;

		{
			parsed: parser::TypeName #\,
			file: src::File#&}:
			Type(parsed, file),
			Name(parsed->Name, file),
			NoDecay(parsed->NoDecay);
	}

	TupleType -> Type
	{
		# FINAL type() TypeType := :tuple;

		Types: Type - std::Dynamic - std::Vector;

		{
			parsed: parser::TupleType #\,
			file: src::File #&
		}:	Type(parsed, file)
		{
			FOR(i ::= 0; i < ##parsed->Types; i++)
				Types += :gc(Type::create(parsed->Types[i], file));
		}
	}

	TypeOfExpression -> Type
	{
		# FINAL type() TypeType := :expression;

		Expression: scoper::Expression - std::Dynamic;

		{
			parsed: parser::TypeOfExpression #\,
			file: src::File #&
		}:	Type(parsed, file),
			Expression(:gc, Expression::create(parsed->Expression, file));
	}

	BuiltinType -> Type
	{
		# FINAL type() TypeType := :builtin;

		TYPE Primitive := parser::BuiltinType::Primitive;
		Kind: Primitive;

		{
			parsed: parser::BuiltinType #\,
			file: src::File#&}:
			Type(parsed, file),
			Kind(parsed->Kind);
	}
}