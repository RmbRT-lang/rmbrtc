INCLUDE "variadic.rl"
INCLUDE "generator.rl"
INCLUDE "instance.rl"
INCLUDE "stage.rl"
INCLUDE "resolveable.rl"

::rlc::instantiator Type VIRTUAL
{
	Size: U4-Resolveable;
}

::rlc::instantiator InstanceType -> instantiator::Type, ast::[Config]Type
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
) ast::[Config]Type -std::Dyn
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

		ret!.Modifiers += &&m;
	}

	ret!.Reference := p.Reference; //! Need checks for `[T=Y&&] T!&` etc.
	
	/// There are no more unexpanded variadic types in this stage.
	ret!.Variadic := NULL;

	= &&ret;
}

::rlc::instantiator::type evaluate_core(
	p: ast::[resolver::Config]Type #&,
	ctx: Context #&
) ast::[Config]Type -std::Dyn
{
	/// Construct the atom value of the type, without the generic modifiers.
	TYPE SWITCH(p)
	{
	ast::[resolver::Config]Signature:
	{
		core: ast::[Config]Signature -std::Dyn := :a(BARE);
		prev: ?#& := <<ast::[resolver::Config]Signature #&>>(p);
		core!.IsCoroutine := prev.IsCoroutine;
		core!.Args.reserve(##prev.Args);
		FOR(arg ::= prev.Args.start())
			add_type_to_vector(arg!, core!.Args, ctx);
		= :<>(&&core);
	}
	ast::[resolver::Config]Void:
		= :a.ast::[Config]Void (BARE);
	ast::[resolver::Config]Null:
		= :a.ast::[Config]Null (BARE);
	ast::[resolver::Config]SymbolConstantType:
	{
		prev: ?& := <<ast::[resolver::Config]SymbolConstantType #&>>(p);
		symbol: ast::[Config]SymbolConstantType -std::Dyn := :a(BARE);
		symbol!.Name.NameType := prev.Name.NameType;
		symbol!.Name.Identifier := prev.Name.Identifier;
		IF(prev.Name.TypeAnnotation)
			symbol!.Name.TypeAnnotation :=
				type::resolve(prev.Name.TypeAnnotation!, ctx);
		= :<>(&&symbol);
	}
	ast::[resolver::Config]TupleType:
	{
		prev: ?& := <<ast::[resolver::Config]TupleType #&>>(p);
		tuple: ast::[Config]TupleType -std::Dyn := :a(BARE);
		tuple!.Types.reserve(##prev.Types);
		FOR(t ::= prev.Types.start())
			add_type_to_vector(t!, tuple!.Types, ctx);
		= :<>(&&tuple);
	}
	ast::[resolver::Config]TypeOfExpression:
		= expression::evaluate_type(
			expression::evaluate(
				<<ast::[resolver::Config]TypeOfExpression#&>>(p).Expression!,
				ctx)!);
	ast::[resolver::Config]TypeName:
	{
		prev: ?#& := <<ast::[resolver::Config]TypeName #&>>(p);
		= resolve_symbol(prev.Name, prev.NoDecay, ctx);
	}
	ast::[resolver::Config]BuiltinType:
	{
		prev: ?& := <<ast::[resolver::Config]BuiltinType #&>>(p);
		builtin: ast::[Config]BuiltinType -std::Dyn := :a(BARE);
		builtin!.Kind := prev.Kind;
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
) ast::[Config]Type-std::Dyn
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