INCLUDE "stage.rl"
INCLUDE "controllabel.rl"
INCLUDE "varorexpression.rl"

::rlc::parser::statement
{
	parse(p: Parser&) ast::[Config]Statement-std::DynOpt
	{
		ret: ast::[Config]Statement - std::Dyn (BARE);
		IF(detail::parse_impl(p, ret, parse_assert)
		|| detail::parse_impl(p, ret, parse_die)
		|| detail::parse_impl(p, ret, parse_yield)
		|| detail::parse_impl(p, ret, parse_sleep)
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
		v: T (BARE);
		IF(parse_fn(p, v))
		{
			ret := :dup(&&v);
			= TRUE;
		}
		= FALSE;
	}

	(// A single statement, such as a loop's body or an if/else clause. /)
	parse_body(p: Parser &) ast::[Config]Statement - std::DynOpt
	{
		ret: ast::[Config]Statement - std::Dyn (BARE);
		IF(detail::parse_impl(p, ret, parse_assert)
		|| detail::parse_impl(p, ret, parse_die)
		|| detail::parse_impl(p, ret, parse_yield)
		|| detail::parse_impl(p, ret, parse_sleep)
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

	parse_body_x(p: Parser &) ast::[Config]Statement - std::Dyn
	{
		IF:!(stmt ::= parse_body(p))
			p.fail("expected statement");
		= :!(&&stmt);
	}

	parse_assert(
		p: Parser &,
		out: ast::[Config]AssertStatement &
	) BOOL
	{
		IF(!p.consume(:assert))
			= FALSE;

		t: Trace(&p, "assert statement");

		p.expect(:parentheseOpen);

		IF(exp ::= parser::expression::parse(p))
			out.Expression := :!(&&exp);
		ELSE p.fail("expected expression");

		p.expect(:parentheseClose);
		p.expect(:semicolon);
		= TRUE;
	}

	parse_die(
		p: Parser &,
		out: ast::[Config]DieStatement &
	) BOOL
	{
		IF(!p.consume(:die))
			= FALSE;

		t: Trace(&p, "die statement");

		out.Message := :a(BARE);
		IF(!expression::parse_string(p, out.Message!))
			out.Message := NULL;

		p.expect(:semicolon);
		= TRUE;
	}

	parse_yield(
		p: Parser &,
		out: ast::[Config]YieldStatement &
	) BOOL
		:= p.consume_seq(:tripleDot, :semicolon);

	parse_sleep(
		p: Parser &,
		out: ast::[Config]SleepStatement &
	) BOOL
	{
		IF(p.match_ahead(:semicolon) || !p.consume(:tripleDot))
			= FALSE;
		t: Trace(&p, "sleep statement");
		out.Duration := expression::parse_x(p);
		p.expect(:semicolon);
		= TRUE;
	}


	parse_block(
		p: Parser&,
		out: ast::[Config]BlockStatement &
	) BOOL
	{
		IF(!p.consume(:braceOpen))
			= FALSE;

		_ ::= p.track_locals();

		IF(p.consume(:semicolon))
		{
			p.expect(:braceClose);
			= TRUE;
		}

		WHILE(!p.consume(:braceClose))
		{
			IF(stmt ::= parser::statement::parse(p))
				out.Statements += :!(&&stmt);
			ELSE
				p.fail("expected statement or '}'");
		}

		= TRUE;
	}


	parse_if(
		p: Parser &,
		out: ast::[Config]IfStatement &
	) BOOL
	{
		IF(!p.consume(:if))
			= FALSE;

		t: Trace(&p, "if statement");
		out.RevealsVariable := p.consume(:colon);
		out.Label := control_label::parse(p);
		out.Negated := p.consume(:exclamationMark);
		p.expect(:parentheseOpen);

		val ::= out.RevealsVariable
			?? <ast::[Config]VarOrExpr-std::DynOpt>(
				variable::parse_local(p, FALSE))
			: var_or_exp::parse(p);

		IF(!val)
			p.fail(out.RevealsVariable
				?? "expected variable"
				:  "expected variable or expression");

		IF(!out.Negated && p.consume(:semicolon))
		{
			<ast::[Config]VarOrExpr-std::DynOpt &>(
				out.Init) := &&val;
			IF!(val := var_or_exp::parse(p))
				p.fail("expected variable or expression");
		}
		<ast::[Config]VarOrExpr-std::Dyn &>(
			out.Condition) := :!(&&val);

		p.expect(:parentheseClose);

		out.Then := parser::statement::parse_body_x(p);

		IF(p.consume(:else))
			out.Else := parser::statement::parse_body_x(p);

		= TRUE;
	}


	parse_variable(
		p: Parser &,
		out: ast::[Config]VariableStatement &
	) BOOL
	{
		out.Static := p.consume(:static);
		IF(v ::= parser::variable::parse_local(p, TRUE))
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
		out: ast::[Config]ExpressionStatement &
	) BOOL
	{
		IF:!(x ::= parser::expression::parse(p))
			= FALSE;
		out.Expression := :!(&&x);
		p.expect(:semicolon);
		= TRUE;
	}

	parse_return(
		p: Parser &,
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
		out: ast::[Config]TryStatement &
	) BOOL
	{
		IF(!p.consume(:try))
			= FALSE;

		out.Body := statement::parse_body_x(p);

		FOR(catch: ast::[Config]CatchStatement (BARE);
			detail::parse_catch(p, catch);)
			out.Catches += &&catch;

		IF(p.consume(:finally))
			IF(!(out.Finally := parser::statement::parse_body(p)))
				p.fail("expected statement");
		ELSE
			out.Finally := NULL;

		= TRUE;
	}


	::detail parse_catch(
		p: Parser &,
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
			IF(!(out.Exception := :parsed(variable::parse_catch(p))))
				p.fail("expected variable");
		}
		p.expect(:parentheseClose);

		out.Body := statement::parse_body_x(p);

		RETURN TRUE;
	}


	parse_throw(
		p: Parser &,
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
		out: ast::[Config]LoopStatement &
	) BOOL
	{
		IF(!p.match(:do)
		&& !p.match(:for)
		&& !p.match(:while))
			= FALSE;

		loop::parse_loop_head(p, out);

		out.Body := statement::parse_body_x(p);

		IF(out.is_post_condition())
			IF(!loop::parse_for_head(p, out)
			&& !loop::parse_while_head(p, out))
				p.fail("expected 'FOR' or 'WHILE'");

		= TRUE;
	}

	::loop parse_loop_head(
		p: Parser &,
		out: ast::[Config]LoopStatement &
	) VOID
	{
		out.Type := :condition;
		IF(!parse_do_head(p, out)
		&& !parse_for_head(p, out)
		&& !parse_while_head(p, out))
			p.fail("expected loop head");
	}

	::loop parse_do_head(
		p: Parser &,
		out: ast::[Config]LoopStatement &
	) BOOL
	{
		IF(!p.consume(:do))
			= FALSE;

		out.Type := :postCondition;

		out.Label := control_label::parse(p);
		p.expect(:parentheseOpen);
		loop::parse_initial(p, out);
		p.expect(:parentheseClose);

		= TRUE;
	}

	::loop parse_for_head(
		p: Parser &,
		out: ast::[Config]LoopStatement &
	) BOOL
	{
		IF(!p.consume(:for))
			= FALSE;

		IF(!out.is_post_condition())
			out.Label := control_label::parse(p);
		p.expect(:parentheseOpen);

		IF(!out.is_post_condition())
		{
			parse_initial(p, out);
			IF(p.consume(:semicolon))
			{
				IF(p.consume_seq(:doubleMinus, :parentheseClose))
				{
					out.Type := :reverseRange;
					= TRUE;
				}
				out.Type := :condition;
			} ELSE
			{
				p.expect(:parentheseClose);
				out.Type := :range;
				= TRUE;
			}
		}

		IF(!p.consume(:semicolon))
		{
			parse_condition(p, out);
			p.expect(:semicolon);
		}

		out.PostLoop := expression::parse(p);

		p.expect(:parentheseClose);
		= TRUE;
	}

	::loop parse_while_head(
		p: Parser &,
		out: ast::[Config]LoopStatement &
	) BOOL
	{
		IF(!p.consume(:while))
			= FALSE;

		IF(!out.is_post_condition())
			out.Label := control_label::parse(p);
		p.expect(:parentheseOpen);

		IF(!out.is_post_condition())
		{
			v ::= var_or_exp::parse(p);

			IF(p.consume(:semicolon))
			{
				out.Initial := :parsed(&&v);
				v := var_or_exp::parse(p);
			}

			out.Condition := :parsed(&&v);
		} ELSE
		{
			IF(!(out.Condition := :parsed(expression::parse(p))))
				p.fail("expected expression");
		}

		p.expect(:parentheseClose);
		= TRUE;
	}

	::loop parse_initial(
		p: Parser &,
		out: ast::[Config]LoopStatement &
	) VOID
	{
		out.Initial := :parsed(var_or_exp::parse_opt(p));
	}

	::loop parse_condition(
		p: Parser &,
		out: ast::[Config]LoopStatement &
	) VOID
	{
		out.Condition := :parsed(var_or_exp::parse(p));
	}

	parse_switch(
		p: Parser &,
		out: ast::[Config]SwitchStatement &
	) BOOL
	{
		IF(!p.consume(:switch))
			= FALSE;

		out.Label := control_label::parse(p);
		out.Strict := !p.consume(:questionMark);
		p.expect(:parentheseOpen);

		val ::= var_or_exp::parse(p);

		IF(p.consume(:semicolon))
		{
			out.Initial := :parsed(&&val);
			val := var_or_exp::parse(p);
		}
		out.Value := :parsed(&&val);

		p.expect(:parentheseClose);
		p.expect(:braceOpen);

		DO(case: ast::[Config]CaseStatement (BARE))
		{
			IF(!switch::parse_case(p, case))
				p.fail("expected case");

			out.Cases += &&case;
		} WHILE(!p.consume(:braceClose))

		= TRUE;
	}

	::switch parse_case(
		p: Parser &,
		out: ast::[Config]CaseStatement &
	) BOOL
	{
		IF(!p.consume(:default))
		{
			DO()
				out.Values += expression::parse_x(p);
				WHILE(p.consume(:comma))
		}
		p.expect(:colon);

		out.Body := statement::parse_body_x(p);

		= TRUE;
	}

	parse_type_switch(
		p: Parser &,
		out: ast::[Config]TypeSwitchStatement &
	) BOOL
	{
		IF(!p.match_ahead(:switch) || !p.consume(:type))
			= FALSE;

		p.eat_token()!;
		out.Static := p.consume(:static);

		out.Label := control_label::parse(p);
		out.Strict := !p.consume(:questionMark);
		p.expect(:parentheseOpen);

		val ::= var_or_exp::parse(p);
		IF(p.consume(:semicolon))
		{
			out.Initial := :parsed(&&val);
			val ::= var_or_exp::parse(p);
		}
		out.Value := :parsed(&&val);

		p.expect(:parentheseClose);
		p.expect(:braceOpen);

		DO(case: ast::[Config]TypeCaseStatement (BARE))
		{
			IF(!type_switch::parse_case(p, case))
				p.fail("expected case");

			out.Cases += &&case;
		} WHILE(!p.consume(:braceClose))

		= TRUE;
	}

	::type_switch parse_case(
		p: Parser &,
		out: ast::[Config]TypeCaseStatement &
	) BOOL
	{
		IF(!p.consume(:default))
			DO()
				out.Types += parser::type::parse_x(p);
				WHILE(p.consume(:comma))

		p.expect(:colon);

		out.Body := statement::parse_body_x(p);

		= TRUE;
	}


	parse_break(
		p: Parser &,
		out: ast::[Config]BreakStatement &
	) BOOL
	{
		IF(!p.consume(:break))
			= FALSE;

		out.Label := control_label::parse_ref(p);
		p.expect(:semicolon);

		= TRUE;
	}

	parse_continue(
		p: Parser &,
		out: ast::[Config]ContinueStatement &
	) BOOL
	{
		IF(!p.consume(:continue))
			= FALSE;

		out.Label := control_label::parse_ref(p);
		p.expect(:semicolon);
		= TRUE;
	}
}