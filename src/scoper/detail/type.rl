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
		RETURN ::[Signature]new(<parser::Signature #\>(parsed), file);
	CASE :void:
		RETURN ::[Void]new(<parser::Void #\>(parsed), file);
	CASE :name:
		RETURN ::[TypeName]new(<parser::TypeName #\>(parsed), file);
	CASE :builtin:
		RETURN ::[BuiltinType]new(<parser::BuiltinType #\>(parsed), file);
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
			FOR(i ::= 0; i < parsed->Args.size(); i++)
				Arguments += :gc(Type::create(parsed->Args[i], file));
		}
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

		{
			parsed: parser::TypeName #\,
			file: src::File#&}:
			Type(parsed, file),
			Name(parsed->Name, file);
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