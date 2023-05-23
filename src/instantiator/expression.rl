INCLUDE "statement.rl"
INCLUDE "symbol.rl"
INCLUDE "templateargs.rl"
INCLUDE "number.rl"

::rlc::instantiator::expression evaluate(
	p: ast::[resolver::Config]Expression #&,
	ctx: Context #&
) ast::[Config]Expression -std::Val
{
	TYPE SWITCH(p)
	{
	ast::[resolver::Config]StatementExpression:
	{
		e: ast::[Config]StatementExpression (BARE);
		e.Statement := statement::evaluate(
			<<ast::[resolver::Config]StatementExpression #&>>(p).Statement!,
			ctx);
		= :dup(&&e);
	}
	ast::[resolver::Config]ReferenceExpression:
	{
		e: ast::[Config]ReferenceExpression (BARE);
		/// Resolve any template-dependent paths.
		e.Symbol := resolve_value_symbol(
			<<ast::[resolver::Config]ReferenceExpression #&>>(p).Symbol, ctx);
		= :dup(&&e);
	}
	ast::[resolver::Config]MemberReferenceExpression:
	{
		/// resolve member of lhs' type.
		e: ast::[Config]MemberReferenceExpression (BARE);
		prev: ?& := <<ast::[resolver::Config]MemberReferenceExpression #&>>(p);
		e.Object := expression::evaluate(prev.Object!, ctx);
		lhsType ::= expression::evaluate_type(e.Object.mut_ok());
		TYPE SWITCH(lhsType)
		{
		InstanceType:
		{
			desc: ?#& := <<InstanceType #&>>(lhsType!).type();
			IF:!(scope ::= <<ast::[resolver::Config]ScopeBase #*>>(desc))
				THROW <rlc::ReasonError>(prev.Position,
					"accessing member: type has no members");

			IF:!(member ::= scope->local(prev.Member.Name, 0))
				THROW <rlc::ReasonError>(prev.Member.Position,
					"no such member");
			e.Member.Type := :<>(&&lhsType);
			e.Member.Member := >>member;
			e.Member.Templates := evaluate_template_args(
				prev.Member.Templates, ctx);

			= :dup(&&e);
		}
		DEFAULT:
			THROW <rlc::ReasonError>(prev.Position,
				"accessing member: type has no members");
		}
	}
	ast::[resolver::Config]SymbolConstantExpression:
	{
		e: ast::[Config]SymbolConstantExpression (BARE);
		pr: ?#& := <<ast::[resolver::Config]SymbolConstantExpression #&>>(p);
		annotation: ast::[Config]Type-std::ValOpt;
		IF(pr.Symbol.TypeAnnotation)
			annotation := type::resolve(pr.Symbol.TypeAnnotation!, ctx);
		e.Symbol.NameType := pr.Symbol.NameType;
		e.Symbol.Identifier := pr.Symbol.Identifier;
		e.Symbol.TypeAnnotation := &&annotation;
		= :dup(&&e);
	}
	ast::[resolver::Config]NumberExpression:
	{
		e: ast::[Config]NumberExpression (BARE);
		e.Number := <<ast::[resolver::Config]NumberExpression #&>>(p).Number;
		= :dup(&&e);
	}
	ast::[resolver::Config]BoolExpression:
	{
		e: ast::[Config]BoolExpression (BARE);
		e.Value := <<ast::[resolver::Config]BoolExpression #&>>(p).Value;
		= :dup(&&e);
	}
	ast::[resolver::Config]CharExpression:
	{
		e: ast::[Config]CharExpression (BARE);
		e.Char := <<ast::[resolver::Config]CharExpression #&>>(p).Char;
		= :dup(&&e);
	}
	ast::[resolver::Config]StringExpression:
	{
		e: ast::[Config]StringExpression (BARE);
		e.String := <<ast::[resolver::Config]StringExpression#&>>(p).String;
		= :dup(&&e);
	}
	ast::[resolver::Config]OperatorExpression:
	{
		DIE; //! perform operator overload resolution (no compile time execution yet).
	}
	ast::[resolver::Config]ThisExpression:
		= :a.ast::[Config]ThisExpression (BARE);
	ast::[resolver::Config]NullExpression:
		= :a.ast::[Config]NullExpression (BARE);
	ast::[resolver::Config]BareExpression:
		= :a.ast::[Config]BareExpression (BARE);
	ast::[resolver::Config]CastExpression:
		DIE; //! need custom cast expression instead that points to a constructor instantiation.
	ast::[resolver::Config]SizeofExpression:
		DIE; //! For now just defer to C due to padding etc., probably.
	ast::[resolver::Config]TypeofExpression:
		DIE; //! need a TYPE type and value type.
	}
}

ENUM CastMode {
	rval, /// allows casting to T#&, T&&, T, etc. Only really used for builtin operators.
	exact /// for explicit casts and function calls
}

::rlc::instantiator::expression Expression
{
	Value: ast::[Config]Expression - std::Val \;
	ValueT: ast::[Config]Type -std::Val;

	{...};

	{expr: ast::[Config]Expression - std::Val \}:
		Value := expr,
		ValueT := evaluate_type(Value->mut());


	# is_pointer() BOOL INLINE := Type::is_pointer(ValueT!);
	# is_plain() BOOL INLINE := Type::is_plain(ValueT!);
	# is_const() BOOL INLINE := Type::is_const(ValueT!);

	# is_mutable() BOOL INLINE := !is_const();
	# is_builtin_numeric() ast::Primitive-std::Opt INLINE := Type::is_builtin_numeric(ValueT!);

	# is_same_base_type(t: ast::[Config]Type #&) BOOL INLINE
		:= Type::is_same_base_type(ValueT!, t);
	# is_related_to(t: ast::[Config]Type #&) BOOL INLINE
		:= Type::is_related_to(ValueT!, t);

	# is_rvalue() BOOL INLINE := Type::is_rvalue(ValueT!);
	# is_lvalue() BOOL INLINE := Type::is_lvalue(ValueT!);


	# conversion_error(msg: CHAR#\) VOID {
		THROW <rlc::ReasonError>((*Value)!.Position, msg);
	}

	explicit_static_reference_cast(type: ast::[Config]Type #&) VOID
	{
		ASSERT(ValueT!.Reference != :none);
		ASSERT(type.Reference != :none);

		IF(is_rvalue() && Type::is_lvalue(type))
			conversion_error("cast to lvalue from rvalue");

		IF(is_same_base_type(type)) /// just differing in reference?
		{
			IF(ValueT!.Reference == type.Reference)
				RETURN;
			ASSERT(Type::is_rvalue(type));
			= to_rvalue_reference();
		} ELSE IF(!is_plain() && is_related_to(type))
		{
			DIE "implement inheritance cast";
		} ELSE IF(is_pointer() && Type::is_pointer(type))
			conversion_error("explicit reference cast between incompatible pointers");
		ELSE
			conversion_error("explicit reference cast between incompatible types");
	}

	copy() VOID := construct_implicit_instance(ValueT!);

	to_rvalue_reference() VOID
	{
		SWITCH(ValueT!.Reference)
		{
		:none: = copy();
		:reference, :tempReference: = to_const();
		}
	}

	to_const() VOID
	{
		IF(!is_const())
		{
			*Value := :a.ConstRef(&&*Value);
			Type::make_const(ValueT.mut());
		}
	}

	// Implicit casts can convert anything to an rvalue using implicit construction, explicit casts can only call constructors explicitly or perform reference casts.
	implicit_static_cast_to(type: ast::[Config]Type #&) VOID
	{
		IF!(ValueT! <> type) /// already a perfect match?
			RETURN;

		IF(is_same_base_type(type)) /// T -> T#&, T& -> T#& or something?
		{
			IF(type.Reference == :none) /// needs a fresh instance (for function params)?
				= copy();
			IF(Type::is_rvalue(type))
				= to_rvalue_reference();
			ELSE /// lvalue
			{
				IF(!is_lvalue())
					conversion_error("implicit conversion of rvalue to lvalue");
				RETURN; /// nothing needs to be done.
			}
		}

		/// different type

		IF(Type::is_lvalue(type))
			conversion_error("implicit conversion to lvalue"); // TODO: inheritance.

		= construct_implicit_instance(type);
	}

	/// always creates a new instance.
	construct_implicit_instance(type: ast::[Config]Type #&) VOID
	{
		IF(Type::is_lvalue(type))
			conversion_error("implicit conversion to lvalue");

		IF(p1 ::= Type::is_builtin_numeric(type))
		{
			IF(p0 ::= is_builtin_numeric())
			{
				IF(p0! != p1!)
				{
					*Value := :a.IntConv(p0!, p1!, &&*Value);
					<<ast::[Config]BuiltinType &>>(ValueT.mut()).Kind := p1!;
				}
				RETURN;
			}
			DIE;
		}

		DIE;
	}
}

::rlc::instantiator::expression PrimitiveToBool -> ast::[Config]Expression
{
	Primitive: ast::Primitive;
	Value: ast::[Config]Expression - std::Val;

	{p: ast::Primitive, v: ast::[Config]Expression-std::Val} -> (:at, v!):
		Primitive := p,
		Value := &&v;
}

::rlc::instantiator::expression PointerToBool -> ast::[Config]Expression
{
	Pointer: ast::[Config]Expression - std::Val;
	{ptr: ast::[Config]Expression - std::Val} -> (:at, ptr!):
		Pointer := &&ptr;
}

::rlc::instantiator::expression ConstRef -> ast::[Config]Expression
{
	Value: ast::[Config]Expression - std::Val;
	{#&};
	{v: ast::[Config]Expression - std::Val} -> (:at, v!):
		Value := &&v;
}

::rlc::instantiator::expression IntConv -> ast::[Config]Expression
{
	From: ast::Primitive;
	To: ast::Primitive;
	Expression: ast::[Config]Expression-std::Val;

	{
		from: ast::Primitive,
		to: ast::Primitive,
		v: ast::[Config]Expression-std::Val
	} -> (:at, v!):
		From := from,
		To := to,
		Expression := &&v;
}

::rlc::instantiator::expression AddressToUm -> ast::[Config]Expression
{
	Addr: ast::[Config]Expression-std::Val;

	{addr: ast::[Config]Expression-std::Val} -> (:at, addr!):
		Addr := &&addr;
}

::rlc::instantiator::expression UmToAddress -> ast::[Config]Expression
{
	Int: ast::[Config]Expression - std::Val;
	To: ast::[Config]Type#-std::Val;

	{
		int: ast::[Config]Expression - std::Val,
		to: ast::[Config]Type#-std::Val
	} -> (:at, int!):
		Int := &&int,
		To := &&to;
}

::rlc::instantiator IntBinOp -> ast::[Config]Expression
{
	Type: ast::Primitive;
	Operation: Operator;
	Lhs: ast::[Config]Expression - std::Val;
	Rhs: ast::[Config]Expression - std::Val;

	{
		original: ast::[Config]Expression#&,
		type: ast::Primitive,
		op: Operator,
		lhs: ast::[Config]Expression-std::Val,
		rhs: ast::[Config]Expression-std::Val
	} -> (:at, original):
		Type := type,
		Operation := op,
		Lhs := &&lhs,
		Rhs := &&rhs;
}

/// User-type constructor.
::rlc::instantiator::expression Constructor -> ast::[Config]Expression
{
	Type: ast::[Config]Type#-std::Val;
	Ctor: ast::[Config]Constructor \;
	Arguments: ast::[Config]Expression-std::ValVec;

	{
		original: ast::[Config]Expression #&,
		type: ast::[Config]Type#-std::Val,
		ctor: ast::[Config]Constructor \,
		args: ast::[Config]Expression-std::ValVec
	} -> (:at, original):
		Type := &&type,
		Ctor := ctor,
		Arguments := &&args;
}

/// evaluate type and also do overload resolution etc. This modifies the ingoing expression.
::rlc::instantiator::expression evaluate_type(
	expr: ast::[Config]Expression &
) ast::[Config]Type - std::Val
{
	TYPE SWITCH(expr)
	{
	ast::[Config]NumberExpression:
	{
		ret: NumberType (BARE);
		ret!.Modifiers += :const;
		= :dup(&&ret);
	}
	ast::[Config]CharExpression:
	{
		b: ast::[Config]BuiltinType (BARE);
		b.Kind := :char;
		b.Modifiers += :const;
		= :dup(&&b);
	}
	ast::[Config]BoolExpression:
	{
		b: ast::[Config]BuiltinType (BARE);
		b.Kind := :bool;
		b.Modifiers += :const;
		= :dup(&&b);
	}
	ast::[Config]NullExpression:
		= :a.ast::[Config]Null (BARE);
	ast::[Config]BareExpression:
		= :a.ast::[Config]Bare (BARE);
	ast::[Config]StringExpression: /// CHAR#[N]
	{
		size: ast::[Config]NumberExpression(BARE);
		size.Number := :nat(##<<ast::[Config]StringExpression #&>>(expr).String);

		modifier: ast::type::[Config]Modifier (:const);
		modifier.IsArray := TRUE;
		modifier.ArraySize := :vec(:dup(&&size));

		charArray: ast::[Config]BuiltinType := :manual(ast::Primitive::char);
		charArray.Modifiers += &&modifier;

		= :dup(&&charArray);
	}
	ast::[Config]OperatorExpression:
	{
		op: ast::[Config]OperatorExpression & := >>expr;
		op0: Expression (&op.Operands[0]);

		IF(op0builtin ::= <<ast::[Config]BuiltinType #*>>(op0.Value))
		{
			SWITCH(op.Op)
			{
			:logAnd, :logOr, :logNot:
			{
				op0.implicit_static_cast_to(<ast::[Config]BuiltinType>(:manual(:bool)));
				op1: Expression (&op.Operands[1]);
				op1.implicit_static_cast_to(<ast::[Config]BuiltinType>(:manual(:bool)));
				= :a.ast::[Config]BuiltinType(:manual(:bool));
			}
			:add, :sub, :mul, :div, :mod, :neg:
			{
				IF(!op0.is_builtin_numeric())
					op0.implicit_static_cast_to(<ast::[Config]BuiltinType>(:manual(:int)));
				op1: Expression (&op.Operands[1]);
				op1.construct_implicit_instance(op0.ValueT!);
				res ::= &&op0.ValueT;
				res.mut().Reference := :none;
				Type::enlarge_to_integer(res.mut_ok());
				= &&res;
			}
			:pos:
			{ op0.copy(); = &&op0.ValueT; }
			:valueOf:
				= &&op0.ValueT;
			:addAssign, :subAssign, :mulAssign, :divAssign, :modAssign,
			:bitAndAssign, :bitOrAssign, :bitXorAssign,
			:shiftLeftAssign, :shiftRightAssign,
			:rotateLeftAssign, :rotateRightAssign:
			{
				IF(!op0.is_builtin_numeric())
					op0.conversion_error("arithmetic assignment to non-arithmetic type");
				IF(op0.is_const())
					op0.conversion_error("assignment to constant type");
				op1: Expression (&op.Operands[1]);
				op1.construct_implicit_instance(op0.ValueT!);
				= &&op0.ValueT;
			}
			:assign:
			{
				IF(op0.is_const())
					op0.conversion_error("assignment to constant type");

				op1: Expression (&op.Operands[1]);
				op1.construct_implicit_instance(op0.ValueT!);
				= &&op0.ValueT;
			}
			}
		}
	}
	Constructor:
	{
	}
	}

	DIE;
}