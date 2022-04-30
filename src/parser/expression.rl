INCLUDE "stage.rl"

INCLUDE "expression/operator.rl"

::rlc::parser::expression
{
	parse(p: Parser &) INLINE Expression-std::Dyn
		:= operator::parse(p);

	/// Parses a non-operator expression.
	parse_atom(p: Parser &) Expression-std::Dyn
	{
		start: src::String;
		position: src::Position;

		// Is this a (...) expression?
		IF(p.consume(:parentheseOpen, &start, &position))
		{
			exp ::= expression::parse(p);
			IF(!exp)
				p.fail("expected expression");

			tuple: OperatorExpression-std::Dyn := NULL;
			WHILE(p.consume(:comma))
			{
				IF(!op)
				{
					tuple := std::[OperatorExpression]new();
					tuple->Op := :tuple;
					tuple->Operands += &&exp;
				}

				IF(!(exp := expression::parse(p)))
					p.fail("expected expression");
				tuple->Operands += &&exp;
			}

			end: src::String;
			p.expect(:parentheseClose, &end);

			(/
	For readability, do not track ordinary parentheses, as they are irrelevant to the inner expression, but track tuples' parentheses, as they are essential.
			/)
			IF(tuple)
				(tuple->Position, tuple->Range) := (position, start.span(end));

			RETURN tuple ? &&tuple : &&exp;
		}

		ret: Expression *;
		IF(detail::parse_impl(p, ret, parse_reference)
		|| detail::parse_impl(p, ret, parse_member_reference)
		|| detail::parse_impl(p, ret, parse_symbol_constant)
		|| detail::parse_impl(p, ret, parse_number)
		|| detail::parse_impl(p, ret, parse_bool)
		|| detail::parse_impl(p, ret, parse_char)
		|| detail::parse_impl(p, ret, parse_string)
		|| detail::parse_impl(p, ret, parse_this)
		|| detail::parse_impl(p, ret, parse_null)
		|| detail::parse_impl(p, ret, parse_cast)
		|| detail::parse_impl(p, ret, parse_sizeof)
		|| detail::parse_impl(p, ret, parse_typeof))
		{
			RETURN :gc(ret);
		}

		RETURN NULL;
	}

	::detail [T:TYPE] parse_impl(
		p: Parser &,
		ret: Expression * &,
		parse_fn: ((Parser&, T! &) BOOL)
	) BOOL
	{
		v: T;
		IF(parse_fn(p, v))
		{
			ret := std::dup(&&v);
			RETURN TRUE;
		}
		RETURN FALSE;
	}

	parse_cast(p: Parser&, out: CastExpression &) BOOL
	{
		// (method, open, close, allow multiple args, expect args)
		STATIC lookup: {CastExpression::Kind, tok::Type, tok::Type, BOOL, BOOL}#[](
			(:static, :less, :greater, TRUE, FALSE),
			(:dynamic, :doubleLess, :doubleGreater, FALSE, TRUE),
			(:mask, :tripleLess, :tripleGreater, TRUE, TRUE)
		);
		type: UM;
		FOR(type := 0; type < ##lookup; type++)
			IF(p.consume(lookup[type].(1), &out.Position))
				BREAK;
		IF(type == ##lookup)
			RETURN FALSE;

		t: Trace(&p, "cast expression");

		out.Method := lookup[type].(0);

		IF(!(out.Type := :gc(parser::type::parse(p))))
			p.fail("expected type");

		p.expect(lookup[type].(2));
		p.expect(:parentheseOpen);
		IF(lookup[type].(4) || !p.consume(:parentheseClose))
		{
			DO()
				IF(value ::= expression::parse(p))
					out.Values += :gc(value);
				ELSE
					p.fail("expected expression");
				WHILE(lookup[type].(3) && p.consume(:comma))

			p.expect(:parentheseClose);
		}

		RETURN TRUE;
	}

	parse_sizeof(p: Parser&, out: SizeofExpression&) BOOL
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

	parse_typeof(p: Parser&, out: TypeofExpression&) BOOL
	{
		IF(!p.consume(:type))
			RETURN FALSE;

		t: Trace(&p, "type expression");

		expectType ::= FALSE;
		IF(!(out.Static := p.consume(:static)))
			expectType := p.consume(:type);

		p.expect(:parentheseOpen);
		IF(expectType)
		{
			IF(!(out.Term := :gc(type::parse(p))))
				p.fail("expected type");
		} ELSE
		{
			IF(!(out.Term := :gc(expression::parse(p))))
				p.fail("expected expression");
		}

		p.expect(:parentheseClose);

		RETURN TRUE;
	}
}