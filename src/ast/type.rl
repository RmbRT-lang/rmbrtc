INCLUDE "symbol.rl"
INCLUDE "expression.rl"
INCLUDE "symbolconstant.rl"

::rlc::ast
{
	/// Type | Argument union.
	[Stage: TYPE] TypeOrArgument VIRTUAL {}
	/// Type | CatchVariable union.
	[Stage: TYPE] TypeOrCatchVariable VIRTUAL {}
	/// Either a specific type or a deduced type.
	[Stage: TYPE] MaybeAutoType VIRTUAL {}

	::type
	{
		ENUM ReferenceType
		{
			none,
			reference,
			tempReference
		}

		ENUM Indirection
		{
			plain,
			pointer,
			nonnull,
			expectDynamic,
			maybeDynamic,
			future
		}

		Qualifier
		{
			Const: BOOL;
			Volatile: BOOL;
		}


		(// Modifiers to be applied to auto types. /)
		[Stage: TYPE] Auto -> [Stage]MaybeAutoType
		{
			Qualifier: type::Qualifier;
			Reference: type::ReferenceType;

			{}: Reference(:none);
		}
	}

	::type [Stage:TYPE] Modifier
	{
		Indirection: type::Indirection;
		Qualifier: type::Qualifier;
		IsArray: BOOL;
		ArraySize: [Stage]Expression - std::DynVec;

		{}: Indirection(:plain), IsArray(FALSE);
		:const{}: Indirection(:plain), Qualifier(:const), IsArray(FALSE);
	}

	/// A specific type.
	[Stage: TYPE] Type VIRTUAL ->
		[Stage]TypeOrExpr,
		[Stage]MaybeAutoType,
		[Stage]TypeOrArgument,
		[Stage]TypeOrCatchVariable
	{
		Modifiers: type::[Stage]Modifier-std::Vec;
		Reference: type::ReferenceType;
		Variadic: BOOL;
	}

	[Stage: TYPE] Signature -> [Stage]Type
	{
		Args: [Stage]Type - std::DynVec;
		Ret: [Stage]Type-std::Dyn;
		IsCoroutine: BOOL;
	}

	[Stage: TYPE] Void -> [Stage]Type
	{
	}

	[Stage: TYPE] Null -> [Stage]Type
	{
	}

	[Stage: TYPE] SymbolConstantType -> [Stage]Type
	{
		Name: [Stage]SymbolConstant;
	}

	[Stage: TYPE] TupleType -> [Stage]Type
	{
		Types: [Stage]Type - std::DynVec;
	}

	[Stage: TYPE] TypeOfExpression -> [Stage]Type
	{
		Expression: ast::[Stage]Expression - std::Dyn;
	}

	[Stage: TYPE] TypeName -> [Stage]Type
	{
		Name: Stage::Symbol;
		NoDecay: BOOL;
	}

	[Stage: TYPE] BuiltinType -> [Stage]Type
	{
		ENUM Primitive
		{
			bool,
			char, uchar,
			int, uint,
			sm, um,

			s1, u1,
			s2, u2,
			s4, u4,
			s8, u8
		}

		Kind: Primitive;
	}

	[Stage: TYPE] ThisType -> [Stage]Type
	{
		:cref{} {
			THIS.Reference := :reference;
			THIS.Modifiers += :const;
		}

		:tempRef{} {
			THIS.Reference := :tempReference;
		}
	}
}