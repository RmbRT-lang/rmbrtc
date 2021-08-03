INCLUDE "../type.rl"
INCLUDE "../symbol.rl"

INCLUDE "../../scoper/detail/type.rl"

INCLUDE 'std/vector'
INCLUDE 'std/memory'

::rlc::resolver::detail create_type(
	scope: scoper::Scope #\,
	scopedType: scoper::Type #\
) Type \
{
	SWITCH(type ::= scopedType->type())
	{
	DEFAULT:
		THROW <std::err::Unimplemented>(type.NAME());
	CASE :signature:
		RETURN std::[Signature]new(scope, <scoper::Signature #\>(scopedType));
	CASE :void:
		RETURN std::[Void]new(scope, scopedType);
	CASE :null:
		RETURN std::[Null]new(scope, scopedType);
	CASE :name:
		RETURN std::[ReferenceType]new(scope, <scoper::TypeName #\>(scopedType));
	CASE :symbolConstant:
		RETURN std::[SymbolConstantType]new(scope, <scoper::SymbolConstantType #\>(scopedType));
	CASE :tuple:
		RETURN std::[TupleType]new(scope, <scoper::TupleType #\>(scopedType));
	CASE :expression:
		RETURN std::[TypeOfExpression]new(scope, <scoper::TypeOfExpression #\>(scopedType));
	CASE :builtin:
		RETURN std::[BuiltinType]new(scope, <scoper::BuiltinType #\>(scopedType));
	}
}

::rlc::resolver
{
	ReferenceType -> Type
	{
		# FINAL type() Type::Kind := :reference;

		NoDecay: BOOL;
		Reference: Symbol;

		{scope: scoper::Scope #\, scopedType: scoper::TypeName #\}
		->	Type(scopedType, scope)
		:	Reference(:resolve(*scope, scopedType->Name)),
			NoDecay(scopedType->NoDecay);
	}

	Signature -> Type
	{
		# FINAL type() Type::Kind := :signature;

		Arguments: Type - std::DynVector;
		Result: Type - std::Dynamic;

		{scope: scoper::Scope #\, scopedType: scoper::Signature #\}
		->	Type(scopedType, scope)
		:	Result(:gc, <<<Type>>>(scope, scopedType->Return))
		{
			FOR(it ::= scopedType->Arguments.start(); it; ++it)
				Arguments += :gc(<<<Type>>>(scope, *it));
		}
	}

	Void -> Type
	{
		# FINAL type() Type::Kind := :void;

		{scope: scoper::Scope #\, scopedType: scoper::Type #\}
		->	Type(scopedType, scope);
	}

	Null -> Type
	{
		# FINAL type() Type::Kind := :null;

		{scope: scoper::Scope #\, scopedType: scoper::Type #\}
		->	Type(scopedType, scope);
	}

	SymbolConstantType -> Type
	{
		# FINAL type() Type::Kind := :symbolConstant;

		Name: scoper::String;

		{scope: scoper::Scope #\, scopedType: scoper::SymbolConstantType #\}
		->	Type(scopedType, scope)
		:	Name(scopedType->Name);
	}

	TupleType -> Type
	{
		# FINAL type() Type::Kind := :tuple;

		Types: Type - std::DynVector;

		{scope: scoper::Scope #\, scopedType: scoper::TupleType #\}
		->	Type(scopedType, scope)
		{
			FOR(i ::= 0; i < ##scopedType->Types; i++)
				Types += :gc(<<<Type>>>(scope, scopedType->Types[i]));
		}
	}

	TypeOfExpression -> Type
	{
		# FINAL type() Type::Kind := :expression;

		Expression: resolver::Expression - std::Dynamic;

		{scope: scoper::Scope #\, scopedType: scoper::TypeOfExpression #\}
		->	Type(scopedType, scope)
		:	Expression(:gc, <<<resolver::Expression>>>(scope, scopedType->Expression));
	}

	BuiltinType -> Type
	{
		# FINAL type() Type::Kind := :builtin;

		TYPE Primitive := parser::BuiltinType::Primitive;

		Kind: Primitive;

		{scope: scoper::Scope #\, scopedType: scoper::BuiltinType #\}
		->	Type(scopedType, scope)
		:	Kind(scopedType->Kind);
	}
}