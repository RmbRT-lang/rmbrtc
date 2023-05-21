INCLUDE "variadic.rl"
INCLUDE "generator.rl"
INCLUDE "instance.rl"
INCLUDE "stage.rl"
INCLUDE "resolveable.rl"

INCLUDE 'std/math/limit'

::rlc::instantiator Type
{
	Size: U4-Resolveable;
	{};
	{&&};

	STATIC INT_BITS : U1 := 4;

	STATIC is_const(type: ast::[Config]Type #&) BOOL
		:= type.Modifiers && type.Modifiers.end()!.Qualifier.Const;

	STATIC is_pointer(type: ast::[Config]Type #&) BOOL
	{
		IF(type.Modifiers)
			= FALSE;
		SWITCH?(type.Modifiers.end()!.Indirection) {
		:pointer, :nonnull: = TRUE;
		}
		= FALSE;
	}

	/// instance or reference to instance, no pointer or array or other indirection.
	STATIC is_plain(type: ast::[Config]Type #&) BOOL
	{
		IF(type.Modifiers)
		{
			IF(##type.Modifiers > 1) // at least one level of indirection or array
				= FALSE;
			mod ::= type.Modifiers.start();
			IF(mod!.Indirection != :plain || mod!.IsArray)
				= FALSE;
		}
		= TRUE;
	}

	// Only consider T& as lvalue, instances and temporary values are not lvalues.
	STATIC is_lvalue(type: ast::[Config]Type #&) BOOL
		:= !is_const(type) && type.Reference == :reference;

	/// T, T#&, T&& (T#&& is illegal / normalises to T#&).
	STATIC is_rvalue(type: ast::[Config]Type #&) BOOL
	{
		SWITCH?(type.Reference) { :none, :tempReference: = TRUE; }
		= is_const(type);
	}

	STATIC get_class(ast::[Config]Type #&) Class - std::OptRef := NULL;

	STATIC is_related_to(a: ast::[Config]Type #&, b: ast::[Config]Type #&) BOOL
	{
		IF:!(cls_a ::= get_class(a))
			= FALSE;
		IF:!(cls_b ::= get_class(b))
			= FALSE;
		= cls_a!.inherits_transitively_from(cls_b)
		|| cls_b!.inherits_transitively_from(cls_a);
	}

	STATIC is_builtin_numeric(type: ast::[Config]Type #&) ast::Primitive - std::Opt
	{
		IF(!is_plain(type)) = NULL;
		IF:!(builtin ::= <<ast::[Config]BuiltinType #*>>(&type)) = NULL;
		SWITCH?(builtin->Kind) { :bool, :char, :uchar: = NULL; }
		= :a(builtin->Kind);
	}

	STATIC builtin_numeric_characteristics(type: ast::Primitive) {U1, BOOL}
	{
		SWITCH(type)
		{
		:s1: = (1, TRUE);
		:u1: = (1, FALSE);
		:s2: = (2, TRUE);
		:u2: = (2, FALSE);
		:s4, :int: = (4, TRUE);
		:u4, :uint: = (4, FALSE);
		:s8, :sm: = (8, TRUE);
		:u8, :um: = (8, FALSE);
		}
	}

	STATIC common_builtin_numeric_type(a: ast::Primitive, b: ast::Primitive) ast::Primitive
	{
		ac ::= builtin_numeric_characteristics(a);
		bc ::= builtin_numeric_characteristics(b);
		sign ::= ac.(1) || bc.(1);
		size ::= std::math::max(ac.(0), bc.(0));
		IF(sign) SWITCH(size) {
			1: = :s1;
			2: = :s2;
			4: = :s4;
			8: = :s8;
		} ELSE SWITCH(size) {
			1: = :u1;
			2: = :u2;
			4: = :u4;
			8: = :u8;
		}
	}

	STATIC is_same_base_type(a: ast::[Config]Type #&, b: ast::[Config]Type #&) BOOL
	{
		amod ::= a.Modifiers.end();
		bmod ::= b.Modifiers.end();
		IF(amod && amod!.Indirection == :plain)
			--amod;
		IF(bmod && bmod!.Indirection == :plain)
			--bmod;

		IF(amod() != bmod())
			= FALSE;

		FOR(;amod && bmod; (--amod, --bmod))
			IF(amod! <> bmod!)
				= FALSE;
		= !amod && !bmod;
	}

	STATIC make_const(t: ast::[Config]Type &) VOID
	{
		IF(t.Modifiers)
			t.Modifiers.end()!.Qualifier.Const := :const;
		ELSE t.Modifiers += :const;
	}

	STATIC enlarge_to_integer(type: ast::[Config]Type &) VOID
	{
		builtin: ast::[Config]BuiltinType & := >>type;
		cs ::= builtin_numeric_characteristics(builtin.Kind);
		IF(cs.(0) <= INT_BITS)
			IF(cs.(1)) builtin.Kind := :int;
			ELSE builtin.Kind := :uint;
	}
}

::rlc::instantiator InstanceType -> ast::[Config]Type
{
	Inst: InstanceID #\;

	{inst: InstanceID #\}:
		Inst := inst
	{
		ASSERT(<<ast::[resolver::Config]CoreType #*>>(Inst->Descriptor));
	}

	# type() ast::[resolver::Config]CoreType #\ := >>Inst->Descriptor;
}

::rlc::instantiator [T:TYPE] add_expression_to_vector(
	p: ast::[resolver::Config]Expression #&,
	out: T! &,
	ctx: Context #&
) VOID
{
	IF:!(op ::= <<ast::[resolver::Config]OperatorExpression #*>>(&p))
		out += :<>(expression::evaluate(p, ctx));
	ELSE IF(op->Op != :variadicExpand)
		out += :<>(expression::evaluate(p, ctx));
	ELSE
	{
		_ctx: VariadicContext := :childOf(&ctx);
		FOR(operand: VariadicExpander (op->Position, &_ctx))
			add_expression_to_vector(p, out, _ctx);
	}
}

::rlc::instantiator [T:TYPE] add_type_to_vector(
	p: ast::[resolver::Config]Type #&,
	out: T! &,
	ctx: Context #&
) VOID
{
	IF(p.Variadic)
	{
		_ctx: VariadicContext := :childOf(&ctx);
		FOR(it: VariadicExpander (p.Variadic!, &_ctx))
			out += type::resolve(p, _ctx);
	} ELSE
		out += type::resolve(p, ctx);
}

::rlc::instantiator::type resolve(
	p: ast::[resolver::Config]Type #&,
	ctx: Context #&
) ast::[Config]Type -std::Val
{
	ret ::= type::evaluate_core(p, ctx);

	FOR(mod ::= p.Modifiers.start())
	{
		m: ast::type::[Config]Modifier (BARE);
		m.Indirection := mod!.Indirection;
		m.Qualifier := mod!.Qualifier;
		IF(m.Qualifier.Const == :maybe)
			m.Qualifier.Const := ctx.this_constness();

		m.IsArray := mod!.IsArray;
		FOR(dim ::= mod!.ArraySize.start())
			add_expression_to_vector(dim!, m.ArraySize, ctx);

		ret.mut().Modifiers += &&m;
	}

	ret.mut().Reference := p.Reference; //! Need checks for `[T=Y&&] T!&` etc.
	
	/// There are no more unexpanded variadic types in this stage.
	ret.mut_ok().Variadic := NULL;

	= &&ret;
}

::rlc::instantiator::type evaluate_core(
	p: ast::[resolver::Config]Type #&,
	ctx: Context #&
) ast::[Config]Type -std::Val
{
	/// Construct the atom value of the type, without the generic modifiers.
	TYPE SWITCH(p)
	{
	ast::[resolver::Config]Signature:
	{
		core: ast::[Config]Signature -std::Val := :a(BARE);
		prev: ?#& := <<ast::[resolver::Config]Signature #&>>(p);
		core.mut_ok().IsCoroutine := prev.IsCoroutine;
		core.mut_ok().Args.reserve(##prev.Args);
		FOR(arg ::= prev.Args.start())
			add_type_to_vector(arg!, core.mut_ok().Args, ctx);
		= :<>(&&core);
	}
	ast::[resolver::Config]Void:
		= :a.ast::[Config]Void (BARE);
	ast::[resolver::Config]Null:
		= :a.ast::[Config]Null (BARE);
	ast::[resolver::Config]SymbolConstantType:
	{
		prev: ?& := <<ast::[resolver::Config]SymbolConstantType #&>>(p);
		symbol: ast::[Config]SymbolConstantType -std::Val := :a(BARE);
		symbol.mut_ok().Name.NameType := prev.Name.NameType;
		symbol.mut_ok().Name.Identifier := prev.Name.Identifier;
		IF(prev.Name.TypeAnnotation)
			symbol.mut_ok().Name.TypeAnnotation :=
				type::resolve(prev.Name.TypeAnnotation!, ctx);
		= :<>(&&symbol);
	}
	ast::[resolver::Config]TupleType:
	{
		prev: ?& := <<ast::[resolver::Config]TupleType #&>>(p);
		tuple: ast::[Config]TupleType -std::Val := :a(BARE);
		tuple.mut_ok().Types.reserve(##prev.Types);
		FOR(t ::= prev.Types.start())
			add_type_to_vector(t!, tuple.mut_ok().Types, ctx);
		= :<>(&&tuple);
	}
	ast::[resolver::Config]TypeOfExpression:
		= expression::evaluate_type(
			expression::evaluate(
				<<ast::[resolver::Config]TypeOfExpression#&>>(p).Expression!,
				ctx).mut_ok());
	ast::[resolver::Config]TypeName:
	{
		prev: ?#& := <<ast::[resolver::Config]TypeName #&>>(p);
		= resolve_symbol(prev.Name, prev.NoDecay, ctx);
	}
	ast::[resolver::Config]BuiltinType:
	{
		prev: ?& := <<ast::[resolver::Config]BuiltinType #&>>(p);
		builtin: ast::[Config]BuiltinType -std::Val := :a(BARE);
		builtin.mut_ok().Kind := prev.Kind;
		= :<>(&&builtin);
	}
	ast::[resolver::Config]ThisType:
		= :dup(ctx.this_type());
	}
}

::rlc::instantiator::type resolve_symbol(
	p: _, //resolver::Config::Symbol+ #&,
	noDecay: BOOL,
	ctx: Context #&
) ast::[Config]Type-std::Val
{
	THROW;
	(//
	instance ::= ctx.resolve_symbol(p);

	TYPE SWITCH(instance->Descriptor)
	{
	ast::[resolver::Config]Typedef:
	ast::[resolver::Config]Class;
	}/)
}