INCLUDE "symbol.rl"
INCLUDE "expression.rl"
INCLUDE "symbolconstant.rl"

::rlc::ast
{
	/// Type | Argument union.
	[Stage: TYPE] TypeOrArgument VIRTUAL
	{
		<<<
			p: [Stage::Prev+]TypeOrArgument #\,
			f: Stage::PrevFile+,
			s: Stage &
		>>> THIS-std::Dyn
		{
			TYPE SWITCH(p)
			{
			[Stage::Prev+]Type:
				= <<<[Stage]Type>>>(
					<<[Stage::Prev+]Type #\>>(p), f, s);
			[Stage::Prev+]Argument:
				= :dup(<[Stage]Argument>(:transform(
					<<[Stage::Prev+]Argument #&>>(*p), f, s)));
			}
		}
	}

	/// Type | CatchVariable union.
	[Stage: TYPE] TypeOrCatchVariable VIRTUAL
	{
		<<<
			p: [Stage::Prev+]TypeOrCatchVariable #\,
			f: Stage::PrevFile+,
			s: Stage &
		>>> THIS-std::Dyn
		{
			TYPE SWITCH(p)
			{
			[Stage::Prev+]Type:
				= <<<[Stage]Type>>>(
					<<[Stage::Prev+]Type #\>>(p), f, s);
			[Stage::Prev+]CatchVariable:
				= :dup(<[Stage]CatchVariable>(:transform(
					<<[Stage::Prev+]CatchVariable #&>>(*p), f, s)));
			}
		}
	}

	/// Either a specific type or a deduced type.
	[Stage: TYPE] MaybeAutoType VIRTUAL
	{
		<<<
			p: [Stage::Prev+]MaybeAutoType #\,
			f: Stage::PrevFile+,
			s: Stage &
		>>> THIS-std::Dyn
		{
			TYPE SWITCH(p)
			{
			[Stage::Prev+]Type:
				= <<<[Stage]Type>>>(
					<<[Stage::Prev+]Type #\>>(p), f, s);
			type::[Stage::Prev+]Auto:
				= :dup(<type::[Stage]Auto>(:transform(
					<<type::[Stage::Prev+]Auto #&>>(*p))));
			}
		}
	}

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
			future,
			processHandle,
			atomic
		}

		ENUM Constness
		{
			none,
			maybe,
			const
		}

		Qualifier
		{
			Const: Constness;
			Volatile: BOOL;

			{}: Const(:none);
			{c: Constness, v: BOOL}:
				Const := c,
				Volatile := v;
		}


		(// Modifiers to be applied to auto types. /)
		[Stage:TYPE] Auto -> [Stage]MaybeAutoType
		{
			Qualifier: type::Qualifier;
			Reference: type::ReferenceType;

			{}: Reference(:none);

			:transform{p:[Stage::Prev+]Auto #&}:
				Qualifier(p.Qualifier),
				Reference(p.Reference);
		}
	}

	::type [Stage:TYPE] Modifier
	{
		Indirection: type::Indirection;
		Qualifier: type::Qualifier;
		IsArray: BOOL;
		ArraySize: [Stage]Expression - std::DynVec;

		{}: Indirection(:plain), IsArray(FALSE);
		:const{}: Indirection(:plain), Qualifier(:const, FALSE), IsArray(FALSE);

		:transform{
			p: [Stage::Prev+]Modifier #&,
			f: Stage::PrevFile+,
			s: Stage &
		}:
			Indirection := p.Indirection,
			Qualifier := p.Qualifier,
			IsArray := p.IsArray,
			ArraySize := :reserve(##p.ArraySize)
		{
			FOR(sz ::= p.ArraySize.start())
				ArraySize += <<<[Stage]Expression>>>(sz!, f, s);
		}
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

		{}: Reference(:none);

		:transform{
			p: [Stage::Prev+]Type #&,
			f: Stage::PrevFile+,
			s: Stage &
		}:
			Modifiers := :reserve(##p.Modifiers),
			Reference := p.Reference,
			Variadic := p.Variadic
		{
			FOR(m ::= p.Modifiers.start())
				Modifiers += :transform(m!, f, s);
		}

		<<<
			p: [Stage::Prev+]Type #\,
			f: Stage::PrevFile+,
			s: Stage &
		>>> THIS-std::Dyn
		{
			TYPE SWITCH(p)
			{
			[Stage::Prev+]Signature:
				= :dup(<[Stage]Signature>(:transform(
					<<[Stage::Prev+]Signature #&>>(*p), f, s)));
			[Stage::Prev+]Void:
				= :dup(<[Stage]Void>(:transform(
					<<[Stage::Prev+]Void #&>>(*p), f, s)));
			[Stage::Prev+]Null:
				= :dup(<[Stage]Null>(:transform(
					<<[Stage::Prev+]Null #&>>(*p), f, s)));
			[Stage::Prev+]SymbolConstantType:
				= :dup(<[Stage]SymbolConstantType>(:transform(
					<<[Stage::Prev+]SymbolConstantType #&>>(*p), f, s)));
			[Stage::Prev+]TupleType:
				= :dup(<[Stage]TupleType>(:transform(
					<<[Stage::Prev+]TupleType #&>>(*p), f, s)));
			[Stage::Prev+]TypeOfExpression:
				= :dup(<[Stage]TypeOfExpression>(:transform(
					<<[Stage::Prev+]TypeOfExpression #&>>(*p), f, s)));
			[Stage::Prev+]TypeName:
				= :dup(<[Stage]TypeName>(:transform(
					<<[Stage::Prev+]TypeName #&>>(*p), f, s)));
			[Stage::Prev+]BuiltinType:
				= :dup(<[Stage]BuiltinType>(:transform(
					<<[Stage::Prev+]BuiltinType #&>>(*p), f, s)));
			[Stage::Prev+]ThisType:
				= :dup(<[Stage]ThisType>(:transform(
					<<[Stage::Prev+]ThisType #&>>(*p), f, s)));
			}
		}
	}

	[Stage: TYPE] Signature -> [Stage]Type
	{
		Args: [Stage]Type - std::DynVec;
		Ret: [Stage]Type-std::Dyn;
		IsCoroutine: BOOL;

		:transform{
			p: [Stage::Prev+]Signature #&,
			f: Stage::PrevFile+,
			s: Stage &
		} -> (:transform, p, f, s):
			Args := :reserve(##p.Args),
			Ret := <<<[Stage]Type>>>(p.Ret!, f, s),
			IsCoroutine := p.IsCoroutine
		{
			FOR(a ::= p.Args.start())
				Args += <<<[Stage]Type>>>(a!, f, s);
		}
	}

	[Stage: TYPE] Void -> [Stage]Type
	{
		:transform{
			p: [Stage::Prev+]Void #&,
			f: Stage::PrevFile+,
			s: Stage &
		} -> (:transform, p, f, s);
	}

	[Stage: TYPE] Null -> [Stage]Type
	{
		:transform{
			p: [Stage::Prev+]Null #&,
			f: Stage::PrevFile+,
			s: Stage &
		} -> (:transform, p, f, s);
	}

	[Stage: TYPE] SymbolConstantType -> [Stage]Type
	{
		Name: [Stage]SymbolConstant;

		:transform{
			p: [Stage::Prev+]SymbolConstantType #&,
			f: Stage::PrevFile+,
			s: Stage &
		} -> (:transform, p, f, s):
			Name := :transform(p.Name, f, s);
	}

	[Stage: TYPE] TupleType -> [Stage]Type
	{
		Types: [Stage]Type - std::DynVec;

		:transform{
			p: [Stage::Prev+]TupleType #&,
			f: Stage::PrevFile+,
			s: Stage &
		} -> (:transform, p, f, s):
			Types := :reserve(##p.Types)
		{
			FOR(t ::= p.Types.start())
				Types += <<<[Stage]Type>>>(t!, f, s);
		}
	}

	[Stage: TYPE] TypeOfExpression -> [Stage]Type
	{
		Expression: ast::[Stage]Expression - std::Dyn;

		:transform{
			p: [Stage::Prev+]TypeOfExpression #&,
			f: Stage::PrevFile+,
			s: Stage &
		} -> (:transform, p, f, s):
			Expression := <<<ast::[Stage]Expression>>>(p.Expression!, f, s);
	}

	[Stage: TYPE] TypeName -> [Stage]Type
	{
		Name: Stage::Symbol;
		NoDecay: BOOL;

		:transform{
			p: [Stage::Prev+]TypeName #&,
			f: Stage::PrevFile+,
			s: Stage &
		} -> (:transform, p, f, s):
			Name := :transform(p.Name, f, s),
			NoDecay := p.NoDecay;
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

		{}: Kind(NOINIT);

		:transform{
			p: [Stage::Prev+]BuiltinType #&,
			f: Stage::PrevFile+,
			s: Stage &
		} -> (:transform, p, f, s):
			Kind := p.Kind;
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

		:transform{
			p: [Stage::Prev+]ThisType #&,
			f: Stage::PrevFile+,
			s: Stage &
		} -> (:transform, p, f, s);
	}
}