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
			f: Stage::PrevFile+,
			s: Stage &,
			parent: [Stage]ScopeBase \
		>>> THIS-std::Dyn
		{
			TYPE SWITCH(p)
			{
			[Stage::Prev+]Type:
				= :<>(<<<[Stage]Type>>>(>>p, f, s, parent));
			[Stage::Prev+]Argument:
				= :a.[Stage]Argument(:transform(>>p, f, s, parent));
			}
		}
	}

	/// Type | CatchVariable union.
	[Stage: TYPE] TypeOrCatchVariable VIRTUAL
	{
		<<<
			p: [Stage::Prev+]TypeOrCatchVariable #&,
			f: Stage::PrevFile+,
			s: Stage &,
			parent: [Stage]ScopeBase \
		>>> THIS-std::Dyn
		{
			TYPE SWITCH(p)
			{
			[Stage::Prev+]Type:
				= :<>(<<<[Stage]Type>>>(>>p, f, s, parent));
			[Stage::Prev+]CatchVariable:
				= :a.[Stage]CatchVariable(:transform(>>p, f, s, parent));
			}
		}
	}

	/// Either a specific type or a deduced type.
	[Stage: TYPE] MaybeAutoType VIRTUAL
	{
		<<<
			p: [Stage::Prev+]MaybeAutoType #&,
			f: Stage::PrevFile+,
			s: Stage &,
			parent: [Stage]ScopeBase \
		>>> THIS-std::Dyn
		{
			TYPE SWITCH(p)
			{
			[Stage::Prev+]Type:
				= :<>(<<<[Stage]Type>>>(>>p, f, s, parent));
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
			f: Stage::PrevFile+,
			s: Stage &,
			parent: [Stage]ScopeBase \
		}:
			Indirection := p.Indirection,
			Qualifier := p.Qualifier,
			IsArray := p.IsArray,
			ArraySize := :reserve(##p.ArraySize)
		{
			FOR(sz ::= p.ArraySize.start())
				ArraySize += :make(sz!, f, s, parent);
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
			f: Stage::PrevFile+,
			s: Stage &,
			parent: [Stage]ScopeBase \
		}:
			Modifiers := :reserve(##p.Modifiers),
			Reference := p.Reference,
			Variadic := p.Variadic
		{
			FOR(m ::= p.Modifiers.start())
				Modifiers += :transform(m!, f, s, parent);
		}

		<<<
			p: [Stage::Prev+]Type #&,
			f: Stage::PrevFile+,
			s: Stage &,
			parent: [Stage]ScopeBase \
		>>> THIS-std::Dyn
		{
			TYPE SWITCH(p)
			{
			[Stage::Prev+]Signature:
				= :a.[Stage]Signature(:transform(>>p, f, s, parent));
			[Stage::Prev+]Void:
				= :a.[Stage]Void(:transform(>>p, f, s, parent));
			[Stage::Prev+]Null:
				= :a.[Stage]Null(:transform(>>p, f, s, parent));
			[Stage::Prev+]SymbolConstantType:
				= :a.[Stage]SymbolConstantType(:transform(>>p, f, s, parent));
			[Stage::Prev+]TupleType:
				= :a.[Stage]TupleType(:transform(>>p, f, s, parent));
			[Stage::Prev+]TypeOfExpression:
				= :a.[Stage]TypeOfExpression(:transform(>>p, f, s, parent));
			[Stage::Prev+]TypeName:
				= :a.[Stage]TypeName(:transform(>>p, f, s, parent));
			[Stage::Prev+]BuiltinType:
				= :a.[Stage]BuiltinType(:transform(>>p, f, s, parent));
			[Stage::Prev+]ThisType:
				= :a.[Stage]ThisType(:transform(>>p, f, s, parent));
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
			f: Stage::PrevFile+,
			s: Stage &,
			parent: [Stage]ScopeBase \
		} -> (:transform, p, f, s, parent):
			Args := :reserve(##p.Args),
			Ret := :make(p.Ret!, f, s, parent),
			IsCoroutine := p.IsCoroutine
		{
			FOR(a ::= p.Args.start())
				Args += :make(a!, f, s, parent);
		}
	}

	[Stage: TYPE] Void -> [Stage]Type
	{
		:transform{
			p: [Stage::Prev+]Void #&,
			f: Stage::PrevFile+,
			s: Stage &,
			parent: [Stage]ScopeBase \
		} -> (:transform, p, f, s, parent);
	}

	[Stage: TYPE] Null -> [Stage]Type
	{
		:transform{
			p: [Stage::Prev+]Null #&,
			f: Stage::PrevFile+,
			s: Stage &,
			parent: [Stage]ScopeBase \
		} -> (:transform, p, f, s, parent);
	}

	[Stage: TYPE] SymbolConstantType -> [Stage]Type
	{
		Name: [Stage]SymbolConstant;

		:transform{
			p: [Stage::Prev+]SymbolConstantType #&,
			f: Stage::PrevFile+,
			s: Stage &,
			parent: [Stage]ScopeBase \
		} -> (:transform, p, f, s, parent):
			Name := :transform(p.Name, f, s, parent);
	}

	[Stage: TYPE] TupleType -> [Stage]Type
	{
		Types: [Stage]Type - std::DynVec;

		:transform{
			p: [Stage::Prev+]TupleType #&,
			f: Stage::PrevFile+,
			s: Stage &,
			parent: [Stage]ScopeBase \
		} -> (:transform, p, f, s, parent):
			Types := :reserve(##p.Types)
		{
			FOR(t ::= p.Types.start())
				Types += :make(t!, f, s, parent);
		}
	}

	[Stage: TYPE] TypeOfExpression -> [Stage]Type
	{
		Expression: ast::[Stage]Expression - std::Dyn;

		:transform{
			p: [Stage::Prev+]TypeOfExpression #&,
			f: Stage::PrevFile+,
			s: Stage &,
			parent: [Stage]ScopeBase \
		} -> (:transform, p, f, s, parent):
			Expression := :make(p.Expression!, f, s, parent);
	}

	[Stage: TYPE] TypeName -> [Stage]Type
	{
		Name: Stage::Symbol;
		NoDecay: BOOL;
		# |THIS ? INLINE := (Name, NoDecay);

		:transform{
			p: [Stage::Prev+]TypeName #&,
			f: Stage::PrevFile+,
			s: Stage &,
			parent: [Stage]ScopeBase \
		} -> (:transform, p, f, s, parent):
			Name := :transform(p.Name, f, s, parent),
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
			f: Stage::PrevFile+,
			s: Stage &,
			parent: [Stage]ScopeBase \
		} -> (:transform, p, f, s, parent):
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
			f: Stage::PrevFile+,
			s: Stage &,
			parent: [Stage]ScopeBase \
		} -> (:transform, p, f, s, parent);
	}
}