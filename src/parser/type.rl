INCLUDE "../ast/type.rl"
INCLUDE "stage.rl"
INCLUDE "symbolconstant.rl"

::rlc::parser::type
{
	TYPE Type := Config-ast::Type;
	TYPE Modifier := Config-ast::type::Modifier;
	TYPE Auto := Config-ast::type::Auto;
	TYPE ReferenceType := ast::type::ReferenceType;
	TYPE Indirection := ast::type::Indirection;
	TYPE Qualifier := ast::type::Qualifier;
	TYPE Signature := Config-ast::Signature;
	TYPE Void := Config-ast::Void;
	TYPE Null := Config-ast::Null;
	TYPE SymbolConstantType := Config-ast::SymbolConstantType;
	TYPE Tuple := Config-ast::TupleType;
	TYPE TypeOfExpression := Config-ast::TypeOfExpression;
	TYPE TypeName := Config-ast::TypeName;
	TYPE BuiltinType := Config-ast::BuiltinType;

	parse_reference_type(p: Parser&) ReferenceType
	{
		STATIC table: {tok::Type, ReferenceType}#[](
			(:and, :reference),
			(:doubleAnd, :tempReference));

		FOR(i ::= 0; i < ##table; i++)
			IF(p.consume(table[i].(0)))
				= table[i].(1);

		= :none;
	}

	parse_indirection(p: Parser&) Indirection
	{
		STATIC table: {tok::Type, Indirection}#[](
			(:asterisk, :pointer),
			(:backslash, :nonnull),
			(:doubleDotExclamationMark, :expectDynamic),
			(:doubleDotQuestionMark, :maybeDynamic),
			(:at, :future));

		FOR(i ::= 0; i < ##table; i++)
			IF(p.consume(table[i].(0)))
				= table[i].(1);

		= :plain;
	}

	parse_qualifier(
		p: Parser&,
		out: Qualifier &) BOOL
	{
		start ::= p.progress();
		IF((out.Const := p.consume(:hash)))
			out.Volatile := p.consume(:dollar);
		ELSE IF((out.Volatile := p.consume(:dollar)))
			out.Const := p.consume(:hash);
		
		= p.progress() != start;
	}

	parse_modifier(
		p: Parser&,
		out: Modifier &) BOOL
	{
		start ::= p.progress();
		out.Indirection := parse_indirection(p);
		parse_qualifier(p, out.Qualifier);

		IF(out.IsArray := p.consume(:bracketOpen))
		{
			IF(!p.consume(:bracketClose))
			{
				DO()
				{
					IF:!(bounds ::= expression::parse(p))
						p.fail("expected expression");
					out.ArraySize += &&bounds;
				} WHILE(p.consume(:comma))

				p.expect(:bracketClose);
			}
		}

		= p.progress() != start;
	}

	::detail [T:TYPE] parse_impl(
		p: Parser &,
		ret: ast::[Config]Type - std::Dyn &,
		parse_fn: ((Parser &, T! &) BOOL)) BOOL
	{
		v: T;
		IF(parse_fn(p, v))
		{
			ret := :dup(&&v);
			WHILE(p.consume(:minus))
			{
				next: TypeName;
				IF(!parse_type_name(p, next))
					p.fail("expected symbol");

				tplArg: ast::[Config]TemplateArg(:emplace, &&ret);
				next.Name.Children!.back().Templates += &&tplArg;
				ret := :dup(&&next);
			}
			= TRUE;
		}
		ELSE
			= FALSE;
	}

	parse(
		p: Parser &) Type - std::Dyn
	{
		ret: Type-std::Dyn;
		IF(detail::parse_impl(p, ret, parse_typeof)
		|| detail::parse_impl(p, ret, parse_tuple)
		|| detail::parse_impl(p, ret, parse_signature)
		|| detail::parse_impl(p, ret, parse_void)
		|| detail::parse_impl(p, ret, parse_null)
		|| detail::parse_impl(p, ret, parse_type_name)
		|| detail::parse_impl(p, ret, parse_builtin)
		|| detail::parse_impl(p, ret, parse_symbol_constant))
			= &&ret;
		= NULL;
	}

	::detail parse_generic_part(
		p: Parser&,
		out: Type &) VOID
	{
		FOR(mod: Modifier; parse_modifier(p, mod);)
			out.Modifiers += &&mod;

		out.Reference := parse_reference_type(p);
		out.Variadic := p.consume(:tripleDot);
	}

	parse_auto_no_ref(p: Parser &, out: Auto &) VOID
	{
		parse_qualifier(p, out.Qualifier);
		out.Reference := :none;
	}

	parse_auto(p: Parser&, out: Auto &) VOID
	{
		t: Trace(&p, "auto type specifier");
		hasQualifier ::= parse_qualifier(p, out.Qualifier);
		out.Reference := parse_reference_type(p);
		IF(out.Reference == :none && !hasQualifier)
			p.expect(:questionMark);
	}

	parse_signature(p: Parser&, out: Signature &) BOOL
	{
		t: Trace(&p, "signature");
		// ((T1, T2) Ret)
		IF(!p.consume(:parentheseOpen))
			= FALSE;

		p.expect(:parentheseOpen);

		IF(!p.consume(:parentheseClose))
		{
			DO(arg: Type *)
			{
				IF(arg := type::parse(p))
					out.Args += &&arg;
				ELSE
					p.fail("expected type");
			} WHILE(p.consume(:comma))
			p.expect(:parentheseClose);
		}

		out.IsCoroutine := p.consume(:at);

		IF:!(type ::= type::parse(p))
			p.fail("expected type");
		out.Ret := &&type;

		p.expect(:parentheseClose);

		detail::parse_generic_part(p, out);

		= TRUE;
	}

	parse_void(p: Parser&, out: Void &) BOOL
	{
		IF(!p.consume(:void))
			= FALSE;
		detail::parse_generic_part(p, out);
		= TRUE;
	}

	parse_null(p: Parser &, out: Null &) BOOL
	{
		IF(!p.consume(:null))
			= FALSE;
		detail::parse_generic_part(p, out);
		= TRUE;
	}

	parse_symbol_constant(p: Parser &, out: SymbolConstantType &) BOOL
	{
		IF(c ::= symbol_constant::parse(p))
			out.Name := &&*c;
		ELSE
			= FALSE;

		detail::parse_generic_part(p, out);

		= TRUE;
	}

	parse_tuple(p: Parser &, out: Tuple &) BOOL
	{
		IF(!p.consume(:braceOpen))
			= FALSE;

		IF(t ::= type::parse(p))
			out.Types += :gc(t);
		ELSE p.fail("expected type");
		p.expect(:comma);
		DO()
			IF(t ::= type::parse(p))
				out.Types += &&t;
			ELSE p.fail("expected type");
			WHILE(p.consume(:comma))
		p.expect(:braceClose);

		detail::parse_generic_part(p, out);
		= TRUE;
	}

	parse_typeof(p: Parser &, out: TypeOfExpression &) BOOL
	{
		IF(!p.consume(:type))
			= FALSE;
		p.expect(:parentheseOpen);
		IF(!(out.Expression := expression::parse(p)))
			p.fail("expected expression");
		p.expect(:parentheseClose);

		detail::parse_generic_part(p, out);

		= TRUE;
	}


	parse_type_name(p: Parser&, out: TypeName &) BOOL
	{
		IF(!symbol::parse(p, out.Name))
			= FALSE;
		out.NoDecay := p.consume(:exclamationMark);
		detail::parse_generic_part(p, out);
		= TRUE;
	}

	parse_builtin(p: Parser&, out: BuiltinType &) BOOL
	{
		STATIC table: {tok::Type, ast::[Config]BuiltinType::Primitive}#[](
			(:bool, :bool),
			(:char, :char), (:uchar, :uchar),
			(:int, :int), (:uint,:uint),
			(:sm, :sm), (:um, :um),

			(:s1, :s1), (:u1, :u1),
			(:s2, :s2), (:u2, :u2),
			(:s4, :s4), (:u4, :u4),
			(:s8, :s8), (:u8, :u8));

		FOR(i ::= 0; i < ##table; i++)
			IF(p.consume(table[i].(0)))
			{
				out.Kind := table[i].(1);
				detail::parse_generic_part(p, out);
				= TRUE;
			}

		= FALSE;
	}
}