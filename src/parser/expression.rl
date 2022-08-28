INCLUDE "stage.rl"

INCLUDE "../ast/expression.rl"
INCLUDE "expression/operator.rl"
INCLUDE "symbolconstant.rl"

::rlc::parser::expression
{
	parse(p: Parser &) ast::[Config]Expression-std::Dyn INLINE
		:= op::parse(p);

	/// Parses a non-operator expression.
	parse_atom(p: Parser &) ast::[Config]Expression-std::Dyn
	{
		start: src::String;
		position: src::Position;

		// Is this a (...) expression?
		IF(tok ::= p.consume(:parentheseOpen))
		{
			(start, position) := (tok->Content, tok->Position);
			IF:!(exp ::= expression::parse(p))
				p.fail("expected expression");

			tuple: ast::[Config]OperatorExpression-std::Dyn := NULL;
			WHILE(p.consume(:comma))
			{
				IF(!tuple)
				{
					tuple := :a(BARE);
					tuple->Op := :tuple;
					tuple->Operands += &&exp;
				}

				IF(!(exp := expression::parse(p)))
					p.fail("expected expression");
				tuple->Operands += &&exp;
			}

			end ::= p.expect(:parentheseClose).Content;

			(/
	For readability, do not track ordinary parentheses, as they are irrelevant to the inner expression, but track tuples' parentheses, as they are essential.
			/)
			IF(tuple)
				(tuple->Position, tuple->Range) := (position, start.span(end));

			IF(tuple)
				= &&tuple;
			= &&exp;
		}

		ret: ast::[Config]Expression - std::Dyn;
		IF(detail::parse_impl(p, ret, parse_reference)
		|| detail::parse_impl(p, ret, parse_symbol_constant)
		|| detail::parse_impl(p, ret, parse_number)
		|| detail::parse_impl(p, ret, parse_bool)
		|| detail::parse_impl(p, ret, parse_char)
		|| detail::parse_impl(p, ret, parse_string)
		|| detail::parse_impl(p, ret, parse_this)
		|| detail::parse_impl(p, ret, parse_null)
		|| detail::parse_impl(p, ret, parse_bare)
		|| detail::parse_impl(p, ret, parse_cast)
		|| detail::parse_impl(p, ret, parse_sizeof)
		|| detail::parse_impl(p, ret, parse_typeof))
		{
			= &&ret;
		}

		= NULL;
	}

	::detail [T:TYPE] parse_impl(
		p: Parser &,
		ret: ast::[Config]Expression - std::Dyn &,
		parse_fn: ((Parser&, T! &) BOOL)
	) BOOL
	{
		v: T (BARE);
		IF(parse_fn(p, v))
		{
			ret := :dup(&&v);
			= TRUE;
		}
		= FALSE;
	}

	parse_reference(p: Parser &, out: ast::[Config]ReferenceExpression &) BOOL
		:= symbol::parse(p, out.Symbol);

	parse_symbol_constant(p: Parser &, out: ast::[Config]SymbolConstantExpression &) BOOL
	{
		IF(sym ::= symbol_constant::parse(p))
		{
			out.Symbol := sym!;
			= TRUE;
		}
		= FALSE;
	}

	parse_number(p: Parser &, out: ast::[Config]NumberExpression &) BOOL
	{
		IF:!(n ::= p.consume(:numberLiteral))
			n := p.consume(:floatLiteral);
		IF(n) out.Number := n!;
		= n;
	}

	parse_bool(p: Parser &, out: ast::[Config]BoolExpression &) BOOL
	{
		IF(p.consume(:true))
			out.Value := TRUE;
		ELSE IF(p.consume(:false))
			out.Value := FALSE;
		ELSE
			= FALSE;
		= TRUE;
	}

	parse_char(p: Parser &, out: ast::[Config]CharExpression &) BOOL
	{
		c ::= p.consume(:stringApostrophe);
		IF(c)
			out.Char := c!;
		= c;
	}

	parse_string(p: Parser &, out: ast::[Config]StringExpression &) BOOL
	{
		WHILE(s ::= p.consume(:stringQuote))
			out.String += s!;
		= ##out.String != 0;
	}

	parse_this(p: Parser &, out: ast::[Config]ThisExpression &) BOOL
		:= p.consume(:this);

	parse_null(p: Parser &, out: ast::[Config]NullExpression &) BOOL
		:= p.consume(:null);

	parse_bare(p: Parser &, out: ast::[Config]BareExpression &) BOOL
		:= p.consume(:bare);

	parse_cast(p: Parser&, out: ast::[Config]CastExpression &) BOOL
	{
		// (method, open, close, allow multiple args, expect args)
		STATIC lookup: {ast::[Config]CastExpression::Kind, tok::Type, tok::Type, BOOL, BOOL}#[](
			(:static, :less, :greater, TRUE, FALSE),
			(:dynamic, :doubleLess, :doubleGreater, FALSE, TRUE),
			(:mask, :tripleLess, :tripleGreater, TRUE, TRUE)
		);
		type: UM;
		FOR(type := 0; type < ##lookup; type++)
			IF(tok ::= p.consume(lookup[type].(1)))
			{
				out.Position := tok->Position;
				BREAK;
			}
		IF(type == ##lookup)
			RETURN FALSE;

		t: Trace(&p, "cast expression");

		out.Method := lookup[type].(0);

		IF(!(out.Type := parser::type::parse(p)))
			p.fail("expected type");

		p.expect(lookup[type].(2));
		p.expect(:parentheseOpen);
		IF(lookup[type].(4) || !p.consume(:parentheseClose))
		{
			DO()
			{
				IF:!(value ::= expression::parse(p))
					p.fail("expected expression");
				out.Values += &&value;
			} WHILE(lookup[type].(3) && p.consume(:comma))

			p.expect(:parentheseClose);
		}

		RETURN TRUE;
	}

	parse_sizeof(p: Parser&, out: ast::[Config]SizeofExpression&) BOOL
	{
		IF(!p.consume(:sizeof))
			RETURN FALSE;

		t: Trace(&p, "sizeof expression");

		out.Variadic := p.consume(:tripleDot);

		p.expect(:parentheseOpen);
		IF(p.consume(:hash))
		{
			IF(!(out.Term := expression::parse(p)))
				p.fail("expected expression");
		} ELSE
		{
			IF(!(out.Term := type::parse(p)))
				p.fail("expected type");
		}

		p.expect(:parentheseClose);

		RETURN TRUE;
	}

	parse_typeof(p: Parser&, out: ast::[Config]TypeofExpression&) BOOL
	{
		IF(!p.consume(:type))
			RETURN FALSE;

		t: Trace(&p, "type expression");

		expectType ::= FALSE;
		IF(!(out.StaticExp := p.consume(:static)))
			expectType := p.consume(:type);

		p.expect(:parentheseOpen);
		IF(expectType)
		{
			IF(!(out.Term := type::parse(p)))
				p.fail("expected type");
		} ELSE
		{
			IF(!(out.Term := expression::parse(p)))
				p.fail("expected expression");
		}

		p.expect(:parentheseClose);

		RETURN TRUE;
	}
}