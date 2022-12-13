INCLUDE "symbol.rl"
INCLUDE "expression.rl"
INCLUDE "symbolconstant.rl"

::rlc::ast
{
	/// Type | Argument union.
	[Stage: TYPE] TypeOrArgument VIRTUAL
	{
		<<<
			p: [Stage::Prev+]TypeOrArgument #&,
			ctx: Stage::Context+ #&
		>>> THIS-std::Dyn
		{
			TYPE SWITCH(p)
			{
			[Stage::Prev+]Type:
				= :<>(<<<[Stage]Type>>>(>>p, ctx));
			[Stage::Prev+]Argument:
				= :a.[Stage]Argument(:transform(>>p, ctx));
			}
		}
	}

	/// Type | CatchVariable union.
	[Stage: TYPE] TypeOrCatchVariable VIRTUAL
	{
		<<<
			p: [Stage::Prev+]TypeOrCatchVariable #&,
			ctx: Stage::Context+ #&
		>>> THIS-std::Dyn
		{
			TYPE SWITCH(p)
			{
			[Stage::Prev+]Type:
				= :<>(<<<[Stage]Type>>>(>>p, ctx));
			[Stage::Prev+]CatchVariable:
				= :a.[Stage]CatchVariable(:transform(>>p, ctx));
			}
		}
	}

	/// Either a specific type or a deduced type.
	[Stage: TYPE] MaybeAutoType VIRTUAL
	{
		<<<
			p: [Stage::Prev+]MaybeAutoType #&,
			ctx: Stage::Context+ #&
		>>> THIS-std::Dyn
		{
			TYPE SWITCH(p)
			{
			[Stage::Prev+]Type:
				= :<>(<<<[Stage]Type>>>(>>p, ctx));
			type::[Stage::Prev+]Auto:
				= :a.type::[Stage]Auto(:transform(>>p));
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
			ctx: Stage::Context+ #&
		}:
			Indirection := p.Indirection,
			Qualifier := p.Qualifier,
			IsArray := p.IsArray,
			ArraySize := :reserve(##p.ArraySize)
		{
			FOR(sz ::= p.ArraySize.start())
				ArraySize += :make(sz!, ctx);
		}

		# |THIS ? := (Indirection, Qualifier, IsArray, ArraySize);
		# THIS <> (rhs: THIS #&) S1 := |THIS <> |rhs;
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
		# |THIS ? INLINE := (Modifiers, Reference, Variadic);

		{}: Reference(:none);

		:transform{
			p: [Stage::Prev+]Type #&,
			ctx: Stage::Context+ #&
		}:
			Modifiers := :reserve(##p.Modifiers),
			Reference := p.Reference,
			Variadic := p.Variadic
		{
			FOR(m ::= p.Modifiers.start())
				Modifiers += :transform(m!, ctx);
		}

		<<<
			p: [Stage::Prev+]Type #&,
			ctx: Stage::Context+ #&
		>>> THIS-std::Dyn
		{
			TYPE SWITCH(p)
			{
			[Stage::Prev+]Signature:
				= :a.[Stage]Signature(:transform(>>p, ctx));
			[Stage::Prev+]Void:
				= :a.[Stage]Void(:transform(>>p, ctx));
			[Stage::Prev+]Null:
				= :a.[Stage]Null(:transform(>>p, ctx));
			[Stage::Prev+]SymbolConstantType:
				= :a.[Stage]SymbolConstantType(:transform(>>p, ctx));
			[Stage::Prev+]TupleType:
				= :a.[Stage]TupleType(:transform(>>p, ctx));
			[Stage::Prev+]TypeOfExpression:
				= :a.[Stage]TypeOfExpression(:transform(>>p, ctx));
			[Stage::Prev+]TypeName:
				= :a.[Stage]TypeName(:transform(>>p, ctx));
			[Stage::Prev+]BuiltinType:
				= :a.[Stage]BuiltinType(:transform(>>p, ctx));
			[Stage::Prev+]ThisType:
				= :a.[Stage]ThisType(:transform(>>p, ctx));
			}
		}
	}

	[Stage: TYPE] Signature -> [Stage]Type
	{
		Args: [Stage]Type - std::DynVec;
		Ret: [Stage]Type-std::Dyn;
		IsCoroutine: BOOL;
		# |THIS ? INLINE := (Args, Ret, IsCoroutine);

		:transform{
			p: [Stage::Prev+]Signature #&,
			ctx: Stage::Context+ #&
		} -> (:transform, p, ctx):
			Args := :reserve(##p.Args),
			Ret := :make(p.Ret!, ctx),
			IsCoroutine := p.IsCoroutine
		{
			FOR(a ::= p.Args.start())
				Args += :make(a!, ctx);
		}
	}

	[Stage: TYPE] Void -> [Stage]Type
	{
		:transform{
			p: [Stage::Prev+]Void #&,
			ctx: Stage::Context+ #&
		} -> (:transform, p, ctx);
	}

	[Stage: TYPE] Null -> [Stage]Type
	{
		:transform{
			p: [Stage::Prev+]Null #&,
			ctx: Stage::Context+ #&
		} -> (:transform, p, ctx);
	}

	[Stage: TYPE] SymbolConstantType -> [Stage]Type
	{
		Name: [Stage]SymbolConstant;

		:transform{
			p: [Stage::Prev+]SymbolConstantType #&,
			ctx: Stage::Context+ #&
		} -> (:transform, p, ctx):
			Name := :transform(p.Name, ctx);
	}

	[Stage: TYPE] TupleType -> [Stage]Type
	{
		Types: [Stage]Type - std::DynVec;

		:transform{
			p: [Stage::Prev+]TupleType #&,
			ctx: Stage::Context+ #&
		} -> (:transform, p, ctx):
			Types := :reserve(##p.Types)
		{
			FOR(t ::= p.Types.start())
				Types += :make(t!, ctx);
		}
	}

	[Stage: TYPE] TypeOfExpression -> [Stage]Type
	{
		Expression: ast::[Stage]Expression - std::Dyn;

		:transform{
			p: [Stage::Prev+]TypeOfExpression #&,
			ctx: Stage::Context+ #&
		} -> (:transform, p, ctx):
			Expression := :make(p.Expression!, ctx);
	}

	[Stage: TYPE] TypeName -> [Stage]Type
	{
		Name: Stage::Symbol;
		NoDecay: BOOL;
		# |THIS ? INLINE := (Name, NoDecay);

		:transform{
			p: [Stage::Prev+]TypeName #&,
			ctx: Stage::Context+ #&
		} -> (:transform, p, ctx):
			Name := ctx.transform_symbol(p.Name, 0),
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

		:transform{
			p: [Stage::Prev+]BuiltinType #&,
			ctx: Stage::Context+ #&
		} -> (:transform, p, ctx):
			Kind := p.Kind;
	}

	[Stage: TYPE] ThisType -> [Stage]Type
	{
		:cref{}
		{
			THIS.Reference := :reference;
			THIS.Modifiers += :const;
		}

		:tempRef{}
		{ THIS.Reference := :tempReference; }

		:transform{
			p: [Stage::Prev+]ThisType #&,
			ctx: Stage::Context+ #&
		} -> (:transform, p, ctx);
	}
}