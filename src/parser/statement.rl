INCLUDE "stage.rl"
INCLUDE "controllabel.rl"
INCLUDE "varorexpression.rl"

::rlc::parser::statement
{
	parse(
		p: Parser&,
		locals: ast::LocalPosition &
	) ast::[Config]Statement-std::Dyn
	{
		ret: ast::[Config]Statement - std::Dyn;
		IF(detail::parse_impl(p, ret, locals, parse_assert)
		|| detail::parse_impl(p, ret, locals, parse_block)
		|| detail::parse_impl(p, ret, locals, parse_if)
		|| detail::parse_impl(p, ret, locals, parse_variable)
		|| detail::parse_impl(p, ret, locals, parse_return)
		|| detail::parse_impl(p, ret, locals, parse_try)
		|| detail::parse_impl(p, ret, locals, parse_throw)
		|| detail::parse_impl(p, ret, locals, parse_loop)
		|| detail::parse_impl(p, ret, locals, parse_switch)
		|| detail::parse_impl(p, ret, locals, parse_type_switch)
		|| detail::parse_impl(p, ret, locals, parse_break)
		|| detail::parse_impl(p, ret, locals, parse_continue)
		|| detail::parse_impl(p, ret, locals, parse_expression))
			= ret;
		ELSE
			= NULL;
	}

	::detail [T:TYPE] parse_impl(
		p: Parser &,
		ret: ast::[Config]Statement - std::Dyn &,
		locals: ast::LocalPosition &,
		parse_fn: ((Parser&, ast::LocalPosition &, T! &) BOOL)
	) BOOL
	{
		v: T;
		IF(parse_fn(p, locals, v))
		{
			ret := :dup(&&v);
			= TRUE;
		}
		= FALSE;
	}

	(// A single statement, such as a loop's body or an if/else clause. /)
	parse_body(
		p: Parser &,
		locals: ast::LocalPosition &
	) ast::[Config]Statement - std::Dyn
	{
		ret: ast::[Config]Statement - std::Dyn;
		IF(detail::parse_impl(p, ret, locals, parse_assert)
		|| detail::parse_impl(p, ret, locals, parse_block)
		|| detail::parse_impl(p, ret, locals, parse_if)
		|| detail::parse_impl(p, ret, locals, parse_return)
		|| detail::parse_impl(p, ret, locals, parse_try)
		|| detail::parse_impl(p, ret, locals, parse_throw)
		|| detail::parse_impl(p, ret, locals, parse_loop)
		|| detail::parse_impl(p, ret, locals, parse_switch)
		|| detail::parse_impl(p, ret, locals, parse_type_switch)
		|| detail::parse_impl(p, ret, locals, parse_break)
		|| detail::parse_impl(p, ret, locals, parse_continue)
		|| detail::parse_impl(p, ret, locals, parse_expression))
			RETURN ret;
		ELSE
			RETURN NULL;
	}

	parse_assert(
		p: Parser &,
		ast::LocalPosition&,
		out: ast::[Config]AssertStatement &
	) BOOL
	{
		IF(!p.consume(:assert))
			= FALSE;

		p.expect(:parentheseOpen);

		IF(!(out.Expression := parser::expression::parse(p)))
			p.fail("expected expression");

		p.expect(:parentheseClose);
		p.expect(:semicolon);
		= TRUE;
	}


	parse_block(
		p: Parser&,
		locals: ast::LocalPosition&,
		out: ast::[Config]BlockStatement &
	) BOOL
	{
		IF(!p.consume(:braceOpen))
			= FALSE;

		IF(p.consume(:semicolon))
		{
			p.expect(:braceClose);
			= TRUE;
		}

		WHILE(!p.consume(:braceClose))
		{
			IF(stmt ::= parser::statement::parse(p, locals))
				out.Statements += &&stmt;
			ELSE
				p.fail("expected statement or '}'");
		}

		= TRUE;
	}


	parse_if(
		p: Parser &,
		locals: ast::LocalPosition &,
		out: ast::[Config]IfStatement &
	) BOOL
	{
		IF(!p.consume(:if))
			= FALSE;

		t: Trace(&p, "if statement");
		out.Label := control_label::parse(p);
		p.expect(:parentheseOpen);

		val ::= var_or_exp::parse(p, locals);

		IF(p.consume(:semicolon))
		{
			out.Init := &&val;
			val := var_or_exp::parse(p, locals);
		}

		out.Condition := &&val;

		p.expect(:parentheseClose);

		IF(!(out.Then := parser::statement::parse_body(p, locals)))
			p.fail("expected statement");

		IF(p.consume(:else))
		{
			IF(!(out.Else := statement::parse_body(p, locals)))
				p.fail("expected statement");
		}

		= TRUE;
	}


	parse_variable(
		p: Parser &,
		locals: ast::LocalPosition&,
		out: ast::[Config]VariableStatement &
	) BOOL
	{
		out.Static := p.consume(:static);
		IF(v ::= parser::variable::parse_local(p, TRUE, locals))
		{
			out.Variable := &&*v;
			= TRUE;
		}
		ELSE IF(out.Static)
			p.fail("expected variable");
		= FALSE;
	}

	parse_expression(
		p: Parser &,
		ast::LocalPosition&,
		out: ast::[Config]ExpressionStatement &
	) BOOL
	{
		IF(!(out.Expression := parser::expression::parse(p)))
			= FALSE;
		p.expect(:semicolon);
		= TRUE;
	}

	parse_return(
		p: Parser &,
		ast::LocalPosition&,
		out: ast::[Config]ReturnStatement &
	) BOOL
	{
		IF(!p.consume(:return) && !p.consume(:equal))
			= FALSE;

		out.Expression := parser::expression::parse(p);

		p.expect(:semicolon);
		= TRUE;
	}

	parse_try(
		p: Parser &,
		locals: ast::LocalPosition&,
		out: ast::[Config]TryStatement &
	) BOOL
	{
		IF(!p.consume(:try))
			= FALSE;

		IF(!(out.Body := statement::parse_body(p, locals)))
			p.fail("expected statement");

		FOR(catch: ast::[Config]CatchStatement;
			detail::parse_catch(p, locals, catch);)
			out.Catches += &&catch;

		IF(p.consume(:finally))
			IF(!(out.Finally := parser::statement::parse_body(p, locals)))
				p.fail("expected statement");
		ELSE
			out.Finally := NULL;

		= TRUE;
	}


	::detail parse_catch(
		p: Parser &,
		locals: ast::LocalPosition&,
		out: ast::[Config]CatchStatement &
	) BOOL
	{
		IF(!p.consume(:catch))
			RETURN FALSE;

		t: Trace(&p, "catch clause");

		p.expect(:parentheseOpen);
		IF(p.match(:parentheseClose)
		|| (p.match_ahead(:parentheseClose)
			&& p.consume(:void)))
		{
			out.ExceptionType := :void;
		} ELSE IF(p.consume(:questionMark))
		{
			out.ExceptionType := :any;
		} ELSE
		{
			out.ExceptionType := :specific;
			IF(!(out.Exception := variable::parse_catch(p, locals)))
				p.fail("expected variable");
		}
		p.expect(:parentheseClose);

		IF(!(out.Body := statement::parse_body(p, locals)))
			p.fail("expected statement");

		RETURN TRUE;
	}


	parse_throw(
		p: Parser &,
		ast::LocalPosition&,
		out: ast::[Config]ThrowStatement &
	) BOOL
	{
		IF(!p.consume(:throw))
			= FALSE;

		IF(p.consume(:tripleDot))
			out.ValueType := :rethrow;
		ELSE IF(p.match(:semicolon))
			out.ValueType := :void;
		ELSE
			IF(out.Value := expression::parse(p))
				out.ValueType := :value;
			ELSE
				p.fail("expected expression");

		p.expect(:semicolon);

		= TRUE;
	}


	parse_loop(
		p: Parser &,
		locals: ast::LocalPosition&,
		out: ast::[Config]LoopStatement &
	) BOOL
	{
		IF(!p.match(:do)
		&& !p.match(:for)
		&& !p.match(:while))
			= FALSE;

		loop::parse_loop_head(p, locals, out);

		IF(!(out.Body := statement::parse_body(p, locals)))
			p.fail("expected statement");

		IF(out.IsPostCondition)
			IF(!loop::parse_for_head(p, locals, out)
			&& !loop::parse_while_head(p, locals, out))
				p.fail("expected 'FOR' or 'WHILE'");

		= TRUE;
	}

	::loop parse_loop_head(
		p: Parser &,
		locals: ast::LocalPosition&,
		out: ast::[Config]LoopStatement &
	) VOID
	{
		out.IsPostCondition := FALSE;
		IF(!parse_do_head(p, locals, out)
		&& !parse_for_head(p, locals, out)
		&& !parse_while_head(p, locals, out))
			p.fail("expected loop head");
	}

	::loop parse_do_head(
		p: Parser &,
		locals: ast::LocalPosition&,
		out: ast::[Config]LoopStatement &
	) BOOL
	{
		IF(!p.consume(:do))
			= FALSE;

		out.IsPostCondition := TRUE;

		out.Label := control_label::parse(p);
		p.expect(:parentheseOpen);
		loop::parse_initial(p, locals, out);
		p.expect(:parentheseClose);

		= TRUE;
	}

	::loop parse_for_head(
		p: Parser &,
		locals: ast::LocalPosition&,
		out: ast::[Config]LoopStatement &
	) BOOL
	{
		IF(!p.consume(:for))
			= FALSE;

		IF(!out.IsPostCondition)
			out.Label := control_label::parse(p);
		p.expect(:parentheseOpen);

		IF(!out.IsPostCondition)
		{
			parse_initial(p, locals, out);
			p.expect(:semicolon);
		}

		IF(!p.consume(:semicolon))
		{
			parse_condition(p, locals, out);
			p.expect(:semicolon);
		}

		out.PostLoop := expression::parse(p);

		p.expect(:parentheseClose);
		= TRUE;
	}

	::loop parse_while_head(
		p: Parser &,
		locals: ast::LocalPosition&,
		out: ast::[Config]LoopStatement &
	) BOOL
	{
		IF(!p.consume(:while))
			= FALSE;

		IF(!out.IsPostCondition)
			out.Label := control_label::parse(p);
		p.expect(:parentheseOpen);

		IF(!out.IsPostCondition)
		{
			v ::= var_or_exp::parse(p, locals);

			IF(p.consume(:semicolon))
			{
				out.Initial := &&v;
				v := var_or_exp::parse(p, locals);
			}

			out.Condition := &&v;
		} ELSE
		{
			IF(!(out.Condition := expression::parse(p)))
				p.fail("expected expression");
		}

		p.expect(:parentheseClose);
		= TRUE;
	}

	::loop parse_initial(
		p: Parser &,
		locals: ast::LocalPosition&,
		out: ast::[Config]LoopStatement &
	) VOID
	{
		out.Initial := var_or_exp::parse_opt(p, locals);
	}

	::loop parse_condition(
		p: Parser &,
		locals: ast::LocalPosition&,
		out: ast::[Config]LoopStatement &
	) VOID
	{
		out.Condition := var_or_exp::parse(p, locals);
	}

	parse_switch(
		p: Parser &,
		locals: ast::LocalPosition&,
		out: ast::[Config]SwitchStatement &
	) BOOL
	{
		IF(!p.consume(:switch))
			= FALSE;

		out.Label := control_label::parse(p);
		p.expect(:parentheseOpen);

		val ::= var_or_exp::parse(p, locals);

		IF(p.consume(:semicolon))
		{
			out.Initial := &&val;
			val := var_or_exp::parse(p, locals);
		}
		out.Value := &&val;

		p.expect(:parentheseClose);
		p.expect(:braceOpen);

		DO(case: ast::[Config]CaseStatement)
		{
			IF(!switch::parse_case(p, locals, case))
				p.fail("expected case");

			out.Cases += &&case;
		} WHILE(!p.consume(:braceClose))

		= TRUE;
	}

	::switch parse_case(
		p: Parser &,
		locals: ast::LocalPosition&,
		out: ast::[Config]CaseStatement &
	) BOOL
	{
		IF(!p.consume(:default))
		{
			DO()
			{
				IF(value ::= expression::parse(p))
					out.Values += &&value;
				ELSE
					p.fail("expected expression");
			} WHILE(p.consume(:comma))
		}
		p.expect(:colon);

		IF(!(out.Body := statement::parse_body(p, locals)))
			p.fail("expected statement");

		= TRUE;
	}

	parse_type_switch(
		p: Parser &,
		locals: ast::LocalPosition&,
		out: ast::[Config]TypeSwitchStatement &
	) BOOL
	{
		IF(!p.match_ahead(:switch) || !p.consume(:type))
			= FALSE;

		p.eat_token()!;
		out.Static := p.consume(:static);

		out.Label := control_label::parse(p);
		p.expect(:parentheseOpen);

		val ::= var_or_exp::parse(p, locals);
		IF(p.consume(:semicolon))
		{
			out.Initial := &&val;
			val ::= var_or_exp::parse(p, locals);
		}
		out.Value := &&val;

		p.expect(:parentheseClose);
		p.expect(:braceOpen);

		DO(case: ast::[Config]TypeCaseStatement)
		{
			IF(!type_switch::parse_case(p, locals, case))
				p.fail("expected case");

			out.Cases += &&case;
		} WHILE(!p.consume(:braceClose))

		= TRUE;
	}

	::type_switch parse_case(
		p: Parser &,
		locals: ast::LocalPosition&,
		out: ast::[Config]TypeCaseStatement &
	) BOOL
	{
		IF(!p.consume(:default))
		{
			DO()
			{
				IF(type ::= parser::type::parse(p))
					out.Types += &&type;
				ELSE p.fail("expected type");
			} WHILE(p.consume(:comma))
		}
		p.expect(:colon);

		IF(!(out.Body := statement::parse_body(p, locals)))
			p.fail("expected statement");

		= TRUE;
	}


	parse_break(
		p: Parser &,
		ast::LocalPosition&,
		out: ast::[Config]BreakStatement &
	) BOOL
	{
		IF(!p.consume(:break))
			= FALSE;

		out.Label := control_label::parse(p);
		p.expect(:semicolon);

		= TRUE;
	}

	parse_continue(
		p: Parser &,
		ast::LocalPosition&,
		out: ast::[Config]ContinueStatement &
	) BOOL
	{
		IF(!p.consume(:continue))
			= FALSE;

		out.Label := control_label::parse(p);
		p.expect(:semicolon);
		= TRUE;
	}
}