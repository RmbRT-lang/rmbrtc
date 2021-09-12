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
	TYPE SWITCH(scopedType)
	{
	DEFAULT:
		THROW <std::err::Unimplemented>(TYPE(scopedType));
	CASE scoper::Signature:
		RETURN std::[Signature]new(scope, <scoper::Signature #\>(scopedType));
	CASE scoper::Void:
		RETURN std::[Void]new(scope, scopedType);
	CASE scoper::Null:
		RETURN std::[Null]new(scope, scopedType);
	CASE scoper::TypeName:
		RETURN std::[ReferenceType]new(scope, <scoper::TypeName #\>(scopedType));
	CASE scoper::SymbolConstantType:
		RETURN std::[SymbolConstantType]new(scope, <scoper::SymbolConstantType #\>(scopedType));
	CASE scoper::TupleType:
		RETURN std::[TupleType]new(scope, <scoper::TupleType #\>(scopedType));
	CASE scoper::TypeOfExpression:
		RETURN std::[TypeOfExpression]new(scope, <scoper::TypeOfExpression #\>(scopedType));
	CASE scoper::BuiltinType:
		RETURN std::[BuiltinType]new(scope, <scoper::BuiltinType #\>(scopedType));
	}
}

::rlc::resolver
{
	ReferenceType -> Type
	{
		NoDecay: BOOL;
		Reference: Symbol;

		{scope: scoper::Scope #\, scopedType: scoper::TypeName #\}
		->	Type(scopedType, scope)
		:	Reference(:resolve(*scope, scopedType->Name)),
			NoDecay(scopedType->NoDecay);
	}

	Signature -> Type
	{
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
		{scope: scoper::Scope #\, scopedType: scoper::Type #\}
		->	Type(scopedType, scope);
	}

	Null -> Type
	{
		{scope: scoper::Scope #\, scopedType: scoper::Type #\}
		->	Type(scopedType, scope);
	}

	SymbolConstantType -> Type
	{
		Name: scoper::String;

		{scope: scoper::Scope #\, scopedType: scoper::SymbolConstantType #\}
		->	Type(scopedType, scope)
		:	Name(scopedType->Name);
	}

	TupleType -> Type
	{
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
		Expression: resolver::Expression - std::Dynamic;

		{scope: scoper::Scope #\, scopedType: scoper::TypeOfExpression #\}
		->	Type(scopedType, scope)
		:	Expression(:gc, <<<resolver::Expression>>>(scope, scopedType->Expression));
	}

	BuiltinType -> Type
	{
		TYPE Primitive := parser::BuiltinType::Primitive;

		Kind: Primitive;

		{scope: scoper::Scope #\, scopedType: scoper::BuiltinType #\}
		->	Type(scopedType, scope)
		:	Kind(scopedType->Kind);
	}
}