INCLUDE "stage.rl"

INCLUDE "../ast/expression.rl"
INCLUDE "expression/operator.rl"
INCLUDE "symbolconstant.rl"

::rlc::parser::expression
{
	parse(p: Parser &) ast::[Config]Expression-std::ValOpt INLINE
		:= op::parse(p);

	parse_x(p: Parser &) ast::[Config]Expression-std::Val
	{
		IF:!(x ::= parse(p))
			p.fail("expected expression");
		= :!(&&x);
	}

	/// Parses a non-operator expression.
	parse_atom(
		p: Parser &
	) ast::[Config]Expression-std::ValOpt
	{
		// The start of the expression.
		position ::= p.position();

		// Is this a (...) expression?
		IF(tok ::= p.consume(:parentheseOpen))
		{
			start ::= tok->Content;
			IF:!(exp ::= expression::parse(p))
				p.fail("expected expression");

			tuple: ast::[Config]OperatorExpression-std::ValOpt;
			WHILE(p.consume(:comma))
			{
				IF(!tuple)
				{
					tuple := :a(BARE);
					t ::= tuple.mut_ptr_ok();
					t->LocalPos := p.locals();
					t->Position := position;
					t->Op := :tuple;
					t->Operands += :!(&&exp);
				}

				IF!(exp := expression::parse(p))
					p.fail("expected expression");
				tuple.mut_ok().Operands += :!(&&exp);
			}

			end ::= p.expect(:parentheseClose).Content;

			(/
	For readability, do not track ordinary parentheses, as they are irrelevant to the inner expression, but track tuples' parentheses, as they are essential.
			/)
			IF(tuple)
			{
				tuple.mut_ok().Range := start.span(end);
				= &&tuple;
			}
			= &&exp;
		}

		start ::= p.offset();
		ret: ast::[Config]Expression - std::Val (BARE);
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
		|| detail::parse_impl(p, ret, parse_typeof)
		|| detail::parse_impl(p, ret, parse_copy_rtti)
		|| detail::parse_impl(p, ret, parse_base))
		{
			ret.mut_ok().Range := (start, p.prev_offset() - start);
			ret.mut_ok().Position := position;
			= &&ret;
		}

		= NULL;
	}

	::detail [T:TYPE] parse_impl(
		p: Parser &,
		ret: ast::[Config]Expression - std::Val &,
		parse_fn: ((Parser&, T! &) BOOL)
	) BOOL
	{
		v: T (BARE);
		IF:(ok ::= parse_fn(p, v))
		{
			v.LocalPos := p.locals();
			ret := :dup(&&v);
		}
		= ok;
	}

	parse_reference(p: Parser &, out: ast::[Config]ReferenceExpression &) BOOL
		:= symbol::parse(p, out.Symbol);

	parse_symbol_constant(p: Parser &, out: ast::[Config]SymbolConstantExpression &) BOOL
	{
		IF(sym ::= symbol_constant::parse(p))
		{
			out.Symbol := &&sym!;
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

		IF(type ::= parser::type::parse(p))
			out.Type := :!(&&type);
		ELSE p.fail("expected type");

		p.expect(lookup[type].(2));
		p.expect(:parentheseOpen);
		IF(lookup[type].(4) || !p.consume(:parentheseClose))
		{
			DO()
				out.Values += expression::parse_x(p);
				WHILE(lookup[type].(3) && p.consume(:comma))

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
			IF(term ::= expression::parse(p))
				out.Term := :!(&&term);
			ELSE p.fail("expected expression");
		} ELSE
		{
			IF(term ::= type::parse(p))
				out.Term := :!(&&term);
			ELSE p.fail("expected type");
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
		IF!(out.StaticExp := p.consume(:static))
			expectType := p.consume(:type);

		p.expect(:parentheseOpen);
		IF(expectType)
		{
			IF(term ::= type::parse(p))
				out.Term := :!(&&term);
			ELSE p.fail("expected type");
		} ELSE
		{
			IF(term ::= expression::parse(p))
				out.Term := :!(&&term);
			ELSE p.fail("expected expression");
		}

		p.expect(:parentheseClose);

		RETURN TRUE;
	}

	parse_copy_rtti(p: Parser &, out: ast::[Config]CopyRttiExpression&) BOOL
	{
		IF(!p.consume(:copy_rtti))
			= FALSE;

		t: Trace(&p, "COPY_RTTI expression");
		p.expect(:parentheseOpen);
		out.Source := parse_x(p);
		p.expect(:comma);
		out.Dest := parse_x(p);
		p.expect(:parentheseClose);

		= TRUE;
	}

	parse_base(p: Parser &, out: ast::[Config]BaseExpression&) BOOL
	{
		IF(!p.consume(:greater))
			= FALSE;
		t: Trace(&p, "base expression");

		p.expect(:parentheseOpen);
		IF(tok ::= p.consume(:numberLiteral))
			out.Index := :a(tok!);
		ELSE
		{
			out.Name := :a(BARE);
			IF(!symbol::parse(p, out.Name!))
				p.fail("expected base class index or  name");
		}
		p.expect(:parentheseClose);

		= TRUE;
	}
}