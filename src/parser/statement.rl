INCLUDE "stage.rl"
INCLUDE "controllabel.rl"

::rlc::parser::statement
{
	parse(p: Parser&) ast::[Config]Statement-std::Dyn
	{
		ret: ast::[Config]Statement - std::Dyn;
		IF(detail::parse_impl(p, ret, parse_assert)
		|| detail::parse_impl(p, ret, parse_block)
		|| detail::parse_impl(p, ret, parse_if)
		|| detail::parse_impl(p, ret, parse_variable)
		|| detail::parse_impl(p, ret, parse_return)
		|| detail::parse_impl(p, ret, parse_try)
		|| detail::parse_impl(p, ret, parse_throw)
		|| detail::parse_impl(p, ret, parse_loop)
		|| detail::parse_impl(p, ret, parse_switch)
		|| detail::parse_impl(p, ret, parse_type_switch)
		|| detail::parse_impl(p, ret, parse_break)
		|| detail::parse_impl(p, ret, parse_continue)
		|| detail::parse_impl(p, ret, parse_expression))
			= ret;
		ELSE
			= NULL;
	}

	::detail [T:TYPE] parse_impl(
		p: Parser &,
		ret: ast::[Config]Statement - std::Dyn &,
		parse_fn: ((Parser&, T! &) BOOL)
	) BOOL
	{
		v: T;
		IF(parse_fn(p, v))
		{
			ret := :dup(&&v);
			= TRUE;
		}
		= FALSE;
	}

	(// A single statement, such as a loop's body or an if/else clause. /)
	parse_body(p: Parser &) ast::[Config]Statement - std::Dyn
	{
		ret: ast::[Config]Statement - std::Dyn;
		IF(detail::parse_impl(p, ret, parse_assert)
		|| detail::parse_impl(p, ret, parse_block)
		|| detail::parse_impl(p, ret, parse_if)
		|| detail::parse_impl(p, ret, parse_return)
		|| detail::parse_impl(p, ret, parse_try)
		|| detail::parse_impl(p, ret, parse_throw)
		|| detail::parse_impl(p, ret, parse_loop)
		|| detail::parse_impl(p, ret, parse_switch)
		|| detail::parse_impl(p, ret, parse_type_switch)
		|| detail::parse_impl(p, ret, parse_break)
		|| detail::parse_impl(p, ret, parse_continue)
		|| detail::parse_impl(p, ret, parse_expression))
			RETURN ret;
		ELSE
			RETURN NULL;
	}

	parse_assert(p: Parser &, out: ast::[Config]AssertStatement &) BOOL
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


	parse_block(p: Parser&, out: ast::[Config]BlockStatement &) BOOL
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
			IF(stmt ::= parser::statement::parse(p))
				out.Statements += &&stmt;
			ELSE
				p.fail("expected statement or '}'");
		}

		= TRUE;
	}


	parse_if(p: Parser &, out: ast::[Config]IfStatement &) BOOL
	{
		IF(!p.consume(:if))
			= FALSE;

		t: Trace(&p, "if statement");
		out.Label := control_label::parse(p);
		p.expect(:parentheseOpen);

		val: ast::[Config]VarOrExpr - std::Dyn;
		val.parse(p);

		IF(p.consume(:semicolon))
		{
			out.Init := &&val;
			val.parse(p);
		}

		Condition := &&val;

		p.expect(:parentheseClose);

		IF(!(out.Then := parser::statement::parse_body(p)))
			p.fail("expected statement");

		IF(p.consume(:else))
		{
			IF(!(out.Else := statement::parse_body(p)))
				p.fail("expected statement");
		}

		= TRUE;
	}


	parse_variable(p: Parser &, out: ast::[Config]VariableStatement &) BOOL
	{
		out.Static := p.consume(:static);
		IF(parser::variable::parse_local(p, TRUE, out.Variable))
			= TRUE;
		ELSE IF(out.Static)
			p.fail("expected variable");
		= FALSE;
	}

	parse_expression(p: Parser &, out: ast::[Config]ExpressionStatement &) BOOL
	{
		IF(!(out.Expression := parser::expression::parse(p)))
			= FALSE;
		p.expect(:semicolon);
		= TRUE;
	}

	parse_return(p: Parser &, out: ast::[Config]ReturnStatement &) BOOL
	{
		IF(!p.consume(:return))
			= FALSE;

		out.Expression := parser::expression::parse(p);

		p.expect(:semicolon);
		= TRUE;
	}

	parse_try(p: Parser &, out: ast::[Config]TryStatement &) BOOL
	{
		IF(!p.consume(:try))
			= FALSE;

		IF(!(out.Body := statement::parse_body(p)))
			p.fail("expected statement");

		FOR(catch: ast::[Config]CatchStatement; detail::parse_catch(p);)
			out.Catches += &&catch;

		IF(p.consume(:finally))
			IF(!(out.Finally := parser::statement::parse_body(p)))
				p.fail("expected statement");
		ELSE
			out.Finally := NULL;

		= TRUE;
	}


	::detail parse_catch(p: Parser &, out: ast::[Config]CatchStatement &) BOOL
	{
		IF(!p.consume(:catch))
			RETURN FALSE;

		t: Trace(&p, "catch clause");

		p.expect(:parentheseOpen);
		IF(p.match(:parentheseClose)
		|| (p.match(:void)
			&& p.match_ahead(:parentheseClose)))
		{
			IsVoid := TRUE;
		} ELSE
		{
			IsVoid := FALSE;

			IF(!Exception.parse_catch(p))
				p.fail("expected variable");
		}
		p.expect(:parentheseClose);

		IF(!(Body := :gc(ast::[Config]Statement::parse_body(p))))
			p.fail("expected statement");

		RETURN TRUE;
	}


	parse_throw(p: Parser &, out: ast::[Config]ThrowStatement &) BOOL
	{
		IF(!p.consume(:throw))
			= FALSE;

		IF(p.consume(:tripleDot))
			out.ValueType := Type::rethrow;
		ELSE IF(p.match(:semicolon))
			out.ValueType := Type::void;
		ELSE
			IF(out.Value := expression::parse(p))
				out.ValueType := Type::value;
			ELSE
				p.fail("expected expression");

		p.expect(:semicolon);

		= TRUE;
	}


	parse_loop(p: Parser &, out: ast::[Config]LoopStatement &) BOOL
	{
		IF(!p.match(:do)
		&& !p.match(:for)
		&& !p.match(:while))
			= FALSE;

		loop::parse_loop_head(p, out);

		IF(!(out.Body := statement::parse_body(p)))
			p.fail("expected statement");

		IF(out.IsPostCondition)
			IF(!loop::parse_for_head(p, out)
			&& !loop::parse_while_head(p, out))
				p.fail("expected 'FOR' or 'WHILE'");

		= TRUE;
	}

	::loop parse_loop_head(p: Parser &, out: ast::[Config]LoopStatement &) VOID
	{
		out.IsPostCondition := FALSE;
		IF(!parse_do_head(p, out)
		&& !parse_for_head(p, out)
		&& !parse_while_head(p, out))
			p.fail("expected loop head");
	}

	::loop parse_do_head(p: Parser &, out: ast::[Config]LoopStatement &) BOOL
	{
		IF(!p.consume(:do))
			= FALSE;

		out.IsPostCondition := TRUE;

		parse_label(p, out.Label);
		p.expect(:parentheseOpen);
		loop::parse_initial(p, out);
		p.expect(:parentheseClose);

		= TRUE;
	}

	::loop parse_for_head(p: Parser &) BOOL
	{
		IF(!p.consume(:for))
			= FALSE;

		IF(!out.IsPostCondition)
			out.Label.parse(p);
		p.expect(:parentheseOpen);

		IF(!out.IsPostCondition)
		{
			parse_initial(p);
			p.expect(:semicolon);
		}

		IF(!p.consume(:semicolon))
		{
			parse_condition(p);
			p.expect(:semicolon);
		}

		out.PostLoop := :gc(Expression::parse(p));

		p.expect(:parentheseClose);
		= TRUE;
	}

	::loop parse_while_head(p: Parser &) BOOL
	{
		IF(!p.consume(:while))
			= FALSE;

		IF(!out.IsPostCondition)
			out.Label.parse(p);
		p.expect(:parentheseOpen);

		IF(!out.IsPostCondition)
		{
			IF(variable::help::is_named_variable_start(p))
			v: ast::[Config]VarOrExpr - std::Dyn;
			v.parse(p);
			IF(p.consume(:semicolon))
			{
				out.Initial := &&v;
				v.parse(p);
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

	::loop parse_initial(p: Parser &, out: ast::[Config]LoopStatement &) VOID
	{
		detail::var_or_exp::parse_opt(p, out.Initial);
	}

	::loop parse_condition(p: Parser &, out: ast::[Config]LoopStatement &) VOID
	{
		detail::var_or_exp::parse(p, out.Condition);
	}

	::detail::var_or_exp parse(p: Parser &, out: ast::[Config]LoopStatement &) VOID
	{
		IF(!parse_opt(p, out))
			p.fail("expected variable or expression");
	}

	::detail::var_or_exp parse_opt(p: Parser &, out: ast::[Config]LoopStatement &) BOOL
	{
		v: LocalVariable;
		IF(v.parse_var_decl(p))
			V := std::gcdup(&&v);
		ELSE IF(exp ::= Expression::parse(p))
			V := &&exp;

		= V;
	}

	parse_switch(p: Parser &, out: ast::[Config]SwitchStatement &) BOOL
	{
		IF(!p.consume(:switch))
			= FALSE;

		parse_label(p, out.Label);
		p.expect(:parentheseOpen);

		val: ast::[Config]VarOrExpr - std::Dyn;
		var_or_exp::parse(p, val);

		IF(p.consume(:semicolon))
		{
			out.Initial := &&val;
			va_or_exp::parse(p, Value);
		} ELSE
			out.Value := &&val;

		p.expect(:parentheseClose);
		p.expect(:braceOpen);

		DO(case: ast::[Config]CaseStatement)
		{
			IF(!switch::parse_case(p, case))
				p.fail("expected case");

			out.Cases += &&case;
		} WHILE(!p.consume(:braceClose))

		= TRUE;
	}

	::switch parse_case(p: Parser &) BOOL
	{
		IF(!p.consume(:default))
		{
			DO(value: Expression *)
			{
				IF(!(value := Expression::parse(p)))
					p.fail("expected expression");
				Values += :gc(value);
			} WHILE(p.consume(:comma))
		}
		p.expect(:colon);

		Body := statement::parse_body(p);

		= TRUE;
	}

	parse_type_switch(p: Parser &, out: ast::[Config]TypeSwitchStatement &) BOOL
	{
		IF(!p.match_ahead(:switch) || !p.consume(:type))
			= FALSE;

		p.consume(NULL);
		out.Static := p.consume(:static);

		parse_label(p, out.Label);
		p.expect(:parentheseOpen);

		val: ast::[Config]VarOrExpr - std::Dyn;
		var_or_exp::parse(p, val);

		IF(p.consume(:semicolon))
		{
			out.Initial := &&val;
			var_or_exp::parse(p, Value);
		} ELSE
			out.Value := &&val;

		p.expect(:parentheseClose);
		p.expect(:braceOpen);

		DO(case: ast::[Config]TypeCaseStatement)
		{
			IF(!type_switch::parse_case(p, case))
				p.fail("expected case");

			out.Cases += &&case;
		} WHILE(!p.consume(:braceClose))

		= TRUE;
	}

	::type_switch parse_case(p: Parser &, out: ast::[Config]TypeCaseStatement &) BOOL
	{
		IF(!p.consume(:default))
		{
			DO(type: Type *)
			{
				IF(!(type := parser::type::parse(p)))
					p.fail("expected type");
				out.Types += &&type;
			} WHILE(p.consume(:comma))
		}
		p.expect(:colon);

		Body := :gc(ast::[Config]Statement::parse_body(p));

		= TRUE;
	}


	parse_break(p: Parser &, out: ast::[Config]BreakStatement &) BOOL
	{
		IF(!p.consume(:break))
			= FALSE;

		parse_label(p, out.Label);
		p.expect(:semicolon);

		= TRUE;
	}

	parse_continue(p: Parser &, out: ast::[Config]ContinueStatement &) BOOL
	{
		IF(!p.consume(:continue))
			= FALSE;

		parse_label(p, out.Label);
		p.expect(:semicolon);
		= TRUE;
	}
}