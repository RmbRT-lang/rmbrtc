INCLUDE "../type.rl"

::rlc::instantiator::detail create_type(
	type: resolver::Type #\,
	scope: Scope #&
) Type #\
{
	TYPE SWITCH(type)
	{
	DEFAULT: THROW <std::err::Unimplemented>(TYPE(type));
	resolver::ReferenceType:
		RETURN <Symbol>(<<resolver::ReferenceType #\>>(type)->Reference, scope).type(scope);
	resolver::Signature:
		RETURN scope.type(<Signature>(<<resolver::Signature #\>>(type), scope));
	resolver::Void:
		RETURN scope.type(<Void>());
	resolver::Null:
		RETURN scope.type(<Null>());
	resolver::SymbolConstantType:
		RETURN scope.type(<SymbolConstantType>(<<resolver::SymbolConstantType #\>>(type)));
	resolver::TupleType:
		RETURN scope.type(<TupleType>(<<resolver::TupleType #\>>(type), scope));
	resolver::TypeOfExpression:
		RETURN Type::resolve_expression(<<resolver::TypeOfExpression #\>>(type), scope);
	resolver::BuiltinType:
		RETURN scope.type(<BuiltinType>(<<resolver::BuiltinType #\>>(type)->Kind));
	}
}

::rlc::instantiator CustomType -> Type
{
	Definition: Instance \;

	{definition: Instance \}: Definition(definition);

	# OVERRIDE hash(h: std::Hasher &) VOID { h("instance") (<UM>(Definition)); }
}

::rlc::instantiator Signature -> Type
{
	{ ref: resolver::Signature #\, scope: Scope #& }:
		Args(:reserve(##ref->Arguments)),
		Return(<<<Type>>>(ref->Result!, scope))
	{
		FOR(it ::= ref->Arguments!.start(:ok); it; ++it)
			Args += <<<Type>>>(it!, scope);
	}

	# OVERRIDE hash(h: std::Hasher &) VOID
	{ h('(')('(')(Args)(')')(Return)(')'); }

	Args: Type #\ - std::Vector;
	Return: Type #\;
}

::rlc::instantiator Void -> Type
{
	# OVERRIDE hash(h: std::Hasher &) VOID
	{ h(<std::[CHAR#]Buffer>("VOID", 4)); }
}

::rlc::instantiator Null -> Type
{
	# OVERRIDE hash(h: std::Hasher &) VOID
	{ h(<std::[CHAR#]Buffer>("NULL", 4)); }
}

::rlc::instantiator SymbolConstantType -> Type
{
	# OVERRIDE hash(h: std::Hasher &) VOID
	{ h(':')(Name); }

	{ ref: resolver::SymbolConstantType #\ }
	:	Name(ref->Name);

	Name: scoper::String;
}

::rlc::instantiator TupleType -> Type
{
	# OVERRIDE hash(h: std::Hasher &) VOID
	{ h('(')(Types)(')'); }

	{ ref: resolver::TupleType #\, scope: Scope #& }
	:	Types(:reserve(##ref->Types))
	{
		FOR(type ::= ref->Types.start(); type; ++type)
			Types += <<<Type>>>(type!, scope);
	}

	Types: Type#\ - std::Vector;
}

::rlc::instantiator BuiltinType -> Type
{
	TYPE Primitive := resolver::BuiltinType::Primitive;
	Kind: Primitive;

	# FINAL hash(h: std::Hasher &) VOID
	{ h('#')(<U1>(Kind)); }

	{kind: Primitive}: Kind(kind);
}

::rlc::instantiator WrappedType VIRTUAL -> Type
{
	BaseType: Type #\;

	{baseType: Type #\}: BaseType(baseType);

	# FINAL hash(h: std::Hasher &) VOID
	{ h(<UM>(BaseType)); hash_impl(h); }

	PROTECTED # ABSTRACT hash_impl(h: std::Hasher &) VOID;
}

::rlc::instantiator PointerType -> WrappedType
{
	Nullable: BOOL;

	{base: Type #\, nullable: BOOL}
	->	WrappedType(base)
	:	Nullable(nullable);

	PROTECTED # FINAL hash_impl(h: std::Hasher &) VOID { h('*') VISIT(THIS); }
}

::rlc::instantiator ReferenceType -> WrappedType
{
	Reference: Type::ReferenceType;

	{base: Type #\, reference: Type::ReferenceType}
	->	WrappedType(base)
	:	Reference(reference);

	PROTECTED # FINAL hash_impl(h: std::Hasher &) VOID { h('&') VISIT(THIS); }
}

::rlc::instantiator DynamicType -> WrappedType
{
	ExpectEvaluation: BOOL;

	{base: Type #\, expectEvaluation: BOOL}
	->	WrappedType(base)
	:	ExpectEvaluation(expectEvaluation);

	PROTECTED # FINAL hash_impl(h: std::Hasher &) VOID { h('f') VISIT(THIS); }
}

::rlc::instantiator FutureType -> WrappedType
{
	{base: Type #\}
	->	WrappedType(base);

	PROTECTED # FINAL hash_impl(h: std::Hasher &) VOID { h('@') VISIT(THIS); }
}

::rlc::instantiator QualifiedType -> WrappedType
{
	Const: BOOL;
	Volatile: BOOL;

	{base: Type #\, qualifier: resolver::Type::Qualifier #&}
	->	WrappedType(base)
	:	Const(qualifier.Const),
		Volatile(qualifier.Volatile);

	PROTECTED # FINAL hash_impl(h: std::Hasher &) VOID { h('$') VISIT(THIS); }
}

::rlc::instantiator ArrayType -> WrappedType
{
	Size: Expression - std::DynVector;

	{base: Type #\, :unbounded}
	-> WrappedType(base);

	{
		base: Type #\,
		size: resolver::Expression - std::Dynamic - std::Buffer #&,
		scope: Scope #&
	}
	->	WrappedType(base)
	:	Size(:reserve(##size))
	{
		ASSERT(##size);

		FOR(s ::= size.start(:ok); s; ++s)
			Size += :gc(<<<Expression>>>(s!, scope));
	}

	PROTECTED # FINAL hash_impl(h: std::Hasher &) VOID { h('[') VISIT(THIS) (']'); }
}
