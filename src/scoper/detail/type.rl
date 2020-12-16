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
	CASE parser::TypeType::signature:
		RETURN ::[Signature]new(<parser::Signature #\>(parsed), file);
	CASE parser::TypeType::void:
		RETURN ::[Void]new(<parser::Void #\>(parsed), file);
	CASE parser::TypeType::name:
		RETURN ::[TypeName]new(<parser::TypeName #\>(parsed), file);
	CASE parser::TypeType::builtin:
		RETURN ::[BuiltinType]new(<parser::BuiltinType #\>(parsed), file);
	}
}

::rlc::scoper
{
	Signature -> Type
	{
		# FINAL type() TypeType := TypeType::signature;

		Arguments: std::[std::[Type]Dynamic]Vector;
		Return: std::[Type]Dynamic;

		{
			parsed: parser::Signature #\,
			file: src::File #&}:
			Type(parsed, file),
			Return(Type::create(parsed->Ret, file))
		{
			FOR(i ::= 0; i < parsed->Args.size(); i++)
				Arguments.push_back(Type::create(parsed->Args[i], file));
		}
	}

	Void -> Type
	{
		# FINAL type() TypeType := TypeType::void;

		{
			parsed: parser::Void #\,
			file: src::File#&}:
			Type(parsed, file);
	}

	TypeName -> Type
	{
		# FINAL type() TypeType := TypeType::name;

		Name: Symbol;

		{
			parsed: parser::TypeName #\,
			file: src::File#&}:
			Type(parsed, file),
			Name(parsed->Name, file);
	}

	BuiltinType -> Type
	{
		# FINAL type() TypeType := TypeType::builtin;

		TYPE Primitive := parser::BuiltinType::Primitive;
		Kind: Primitive;

		{
			parsed: parser::BuiltinType #\,
			file: src::File#&}:
			Type(parsed, file),
			Kind(parsed->Kind);
	}
}