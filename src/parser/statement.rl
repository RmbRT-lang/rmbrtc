INCLUDE "parser.rl"
INCLUDE "expression.rl"
INCLUDE "variable.rl"
INCLUDE "controllabel.rl"

INCLUDE 'std/vector'
INCLUDE 'std/memory'

INCLUDE "../util/dynunion.rl"

::rlc::parser
{
	ENUM StatementType
	{
		assert,
		block,
		if,
		variable,
		expression,
		return,
		try,
		throw,
		loop,
		switch,
		break,
		continue
	}

	Statement VIRTUAL
	{
		# ABSTRACT type() StatementType;

		{};
		{Statement &&};

		[T: TYPE]
		PRIVATE STATIC parse_impl(p: Parser &, out: Statement * &) BOOL
		{
			v: T;
			IF(v.parse(p))
			{
				out := std::dup(&&v);
				RETURN TRUE;
			}
			RETURN FALSE;
		}

		STATIC parse(p: Parser&) Statement *
		{
			ret: Statement *;
			IF([AssertStatement]parse_impl(p, ret)
			|| [BlockStatement]parse_impl(p, ret)
			|| [IfStatement]parse_impl(p, ret)
			|| [VariableStatement]parse_impl(p, ret)
			|| [ExpressionStatement]parse_impl(p, ret)
			|| [ReturnStatement]parse_impl(p, ret)
			|| [TryStatement]parse_impl(p, ret)
			|| [ThrowStatement]parse_impl(p, ret)
			|| [LoopStatement]parse_impl(p, ret)
			|| [SwitchStatement]parse_impl(p, ret)
			|| [BreakStatement]parse_impl(p, ret)
			|| [ContinueStatement]parse_impl(p, ret))
				RETURN ret;
			ELSE
				RETURN NULL;
		}

		(// A single statement, such as a loop's body or an if/else clause. /)
		STATIC parse_body(p: Parser &) Statement *
		{
			ret: Statement *;
			IF([AssertStatement]parse_impl(p, ret)
			|| [BlockStatement]parse_impl(p, ret)
			|| [IfStatement]parse_impl(p, ret)
			|| [ExpressionStatement]parse_impl(p, ret)
			|| [ReturnStatement]parse_impl(p, ret)
			|| [TryStatement]parse_impl(p, ret)
			|| [ThrowStatement]parse_impl(p, ret)
			|| [LoopStatement]parse_impl(p, ret)
			|| [SwitchStatement]parse_impl(p, ret)
			|| [BreakStatement]parse_impl(p, ret)
			|| [ContinueStatement]parse_impl(p, ret))
				RETURN ret;
			ELSE
				RETURN NULL;
		}
	}

	AssertStatement -> Statement
	{
		Expression: std::[parser::Expression]Dynamic;

		# FINAL type() StatementType := StatementType::assert;

		parse(p: Parser &) BOOL
		{
			IF(!p.consume(:assert))
				RETURN FALSE;

			p.expect(:parentheseOpen);

			IF(!(Expression := :gc(parser::Expression::parse(p))))
				p.fail("expected expression");

			p.expect(:parentheseClose);
			p.expect(:semicolon);
			RETURN TRUE;
		}
	}

	VarOrExp
	{
		PRIVATE V: util::[LocalVariable; Expression]DynUnion;

		{};
		{v: LocalVariable \}: V(v);
		{v: Expression \}: V(v);

		# is_variable() INLINE BOOL := V.is_first();
		# variable() INLINE LocalVariable \ := V.first();
		# is_expression() INLINE BOOL := V.is_second();
		# expression() INLINE Expression \ := V.second();
		# <BOOL> INLINE := V;

		[T:TYPE] THIS:=(v: T! &&) VarOrExp &
			:= std::help::custom_assign(THIS, <T!&&>(v));

		parse(p: Parser &) VOID
		{
			IF(!parse_opt(p))
				p.fail("expected variable or expression");
		}

		parse_opt(p: Parser &) BOOL
		{
			v: std::[LocalVariable]Dynamic := :gc(std::[LocalVariable]new());
			IF(v->parse_var_decl(p))
				V := v.release();
			ELSE IF(exp ::= Expression::parse(p))
				V := exp;

			RETURN V;
		}
	}

	BlockStatement -> Statement
	{
		Statements: std::[std::[Statement]Dynamic]Vector;

		# FINAL type() StatementType := StatementType::block;

		parse(p: Parser&) BOOL
		{
			IF(!p.consume(:braceOpen))
				RETURN FALSE;

			IF(p.consume(:semicolon))
			{
				p.expect(:braceClose);
				RETURN TRUE;
			}

			WHILE(!p.consume(:braceClose))
			{
				IF(stmt ::= Statement::parse(p))
					Statements += :gc(stmt);
				ELSE
					p.fail("expected statement or '}'");
			}

			RETURN TRUE;
		}
	}

	IfStatement -> Statement
	{
		Label: ControlLabel;

		Init: VarOrExp;
		Condition: VarOrExp;

		Then: std::[Statement]Dynamic;
		Else: std::[Statement]Dynamic;

		# FINAL type() StatementType := StatementType::if;

		parse(p: Parser &) BOOL
		{
			IF(!p.consume(:if))
				RETURN FALSE;

			t: Trace(&p, "if statement");
			Label.parse(p);
			p.expect(:parentheseOpen);

			val: VarOrExp;
			val.parse(p);

			IF(p.consume(:semicolon))
			{
				Init := &&val;
				val.parse(p);
			}

			Condition := &&val;

			p.expect(:parentheseClose);

			IF(!(Then := :gc(Statement::parse_body(p))))
				p.fail("expected statement");

			IF(p.consume(:else))
			{
				IF(!(Else := :gc(Statement::parse_body(p))))
					p.fail("expected statement");
			}

			RETURN TRUE;
		}
	}

	VariableStatement -> Statement
	{
		Variable: LocalVariable;
		Static: BOOL;

		# FINAL type() StatementType := StatementType::variable;

		parse(p: Parser &) BOOL
		{
			Static := p.consume(:static);
			IF(Variable.parse(p, TRUE))
				RETURN TRUE;
			IF(Static)
				p.fail("expected variable");
			RETURN FALSE;
		}
	}

	ExpressionStatement -> Statement
	{
		Expression: std::[parser::Expression]Dynamic;

		# FINAL type() StatementType := StatementType::expression;

		parse(p: Parser &) BOOL
		{
			IF(!(Expression := :gc(parser::Expression::parse(p))))
				RETURN FALSE;

			p.expect(:semicolon);
			RETURN TRUE;
		}
	}

	ReturnStatement -> Statement
	{
		Expression: std::[parser::Expression]Dynamic;

		# FINAL type() StatementType := StatementType::return;

		# is_void() INLINE BOOL := !Expression;

		parse(p: Parser &) BOOL
		{
			IF(!p.consume(:return))
				RETURN FALSE;

			Expression := :gc(parser::Expression::parse(p));

			p.expect(:semicolon);

			RETURN TRUE;
		}
	}

	TryStatement -> Statement
	{
		Body: std::[Statement]Dynamic;
		Catches: std::[CatchStatement]Vector;
		Finally: std::[Statement]Dynamic;

		# FINAL type() StatementType := StatementType::try;

		# has_finally() INLINE BOOL := Finally;

		parse(p: Parser &) BOOL
		{
			IF(!p.consume(:try))
				RETURN FALSE;

			IF(!(Body := :gc(Statement::parse_body(p))))
				RETURN FALSE;

			FOR(catch: CatchStatement; catch.parse(p);)
				Catches += &&catch;

			IF(p.consume(:finally))
				IF(!(Finally := :gc(parser::Statement::parse_body(p))))
					p.fail("expected statement");
			ELSE
				Finally := NULL;

			RETURN TRUE;
		}
	}

	CatchStatement
	{
		IsVoid: BOOL;
		Exception: LocalVariable;
		Body: std::[Statement]Dynamic;

		parse(p: Parser &) BOOL
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

			IF(!(Body := :gc(Statement::parse_body(p))))
				p.fail("expected statement");

			RETURN TRUE;
		}
	}

	ThrowStatement -> Statement
	{
		ENUM Type
		{
			rethrow,
			void,
			value
		}

		ValueType: Type;
		Value: std::[Expression]Dynamic;

		# FINAL type() StatementType := StatementType::throw;

		parse(p: Parser &) BOOL
		{
			IF(!p.consume(:throw))
				RETURN FALSE;

			IF(p.consume(:tripleDot))
				ValueType := Type::rethrow;
			ELSE IF(p.match(:semicolon))
				ValueType := Type::void;
			ELSE
				IF(Value := :gc(Expression::parse(p)))
					ValueType := Type::value;
				ELSE
					p.fail("expected expression");

			p.expect(:semicolon);

			RETURN TRUE;
		}
	}

	LoopStatement -> Statement
	{
		IsPostCondition: BOOL;
		Initial: VarOrExp;
		Condition: VarOrExp;
		Body: std::[Statement]Dynamic;
		PostLoop: std::[Expression]Dynamic;
		Label: ControlLabel;

		# FINAL type() StatementType := StatementType::loop;

		parse(p: Parser &) BOOL
		{
			IF(!p.match(:do)
			&& !p.match(:for)
			&& !p.match(:while))
				RETURN FALSE;

			parse_loop_head(p);

			IF(!(Body := :gc(Statement::parse_body(p))))
				p.fail("expected statement");

			IF(IsPostCondition)
				IF(!parse_for_head(p)
				&& !parse_while_head(p))
					p.fail("expected 'FOR' or 'WHILE'");

			RETURN TRUE;
		}

	PRIVATE:
		parse_loop_head(p: Parser &) VOID
		{
			IsPostCondition := FALSE;
			IF(!parse_do_head(p)
			&& !parse_for_head(p)
			&& !parse_while_head(p))
				p.fail("expected loop head");
		}

		parse_do_head(p: Parser &) BOOL
		{
			IF(!p.consume(:do))
				RETURN FALSE;

			IsPostCondition := TRUE;

			Label.parse(p);
			p.expect(:parentheseOpen);
			parse_initial(p);
			p.expect(:parentheseClose);

			RETURN TRUE;
		}

		parse_for_head(p: Parser &) BOOL
		{
			IF(!p.consume(:for))
				RETURN FALSE;

			IF(!IsPostCondition)
				Label.parse(p);
			p.expect(:parentheseOpen);

			IF(!IsPostCondition)
			{
				parse_initial(p);
				p.expect(:semicolon);
			}

			IF(!p.consume(:semicolon))
			{
				parse_condition(p);
				p.expect(:semicolon);
			}

			PostLoop := :gc(Expression::parse(p));

			p.expect(:parentheseClose);
			RETURN TRUE;
		}

		parse_while_head(p: Parser &) BOOL
		{
			IF(!p.consume(:while))
				RETURN FALSE;

			IF(!IsPostCondition)
				Label.parse(p);
			p.expect(:parentheseOpen);

			IF(!IsPostCondition)
			{
				v: VarOrExp;
				v.parse(p);
				IF(p.consume(:semicolon))
				{
					Initial := &&v;
					v.parse(p);
				}

				Condition := &&v;
			} ELSE
			{
				IF(!(Condition := Expression::parse(p)))
					p.fail("expected expression");
			}

			p.expect(:parentheseClose);
			RETURN TRUE;
		}

		parse_initial(p: Parser &) VOID
		{
			Initial.parse_opt(p);
		}

		parse_condition(p: Parser &) VOID
		{
			Condition.parse(p);
		}
	}

	SwitchStatement -> Statement
	{
		Initial: VarOrExp;
		Value: VarOrExp;
		Cases: std::[CaseStatement]Vector;
		Label: ControlLabel;

		# FINAL type() StatementType := StatementType::switch;

		parse(p: Parser &) BOOL
		{
			IF(!p.consume(:switch))
				RETURN FALSE;

			Label.parse(p);
			p.expect(:parentheseOpen);

			val: VarOrExp;
			val.parse(p);

			IF(p.consume(:semicolon))
			{
				Initial := &&val;
				Value.parse(p);
			} ELSE
				Value := &&val;

			p.expect(:parentheseClose);
			p.expect(:braceOpen);

			DO(case: CaseStatement)
			{
				IF(!case.parse(p))
					p.fail("expected case");

				Cases += &&case;
			} WHILE(!p.consume(:braceClose))

			RETURN TRUE;
		}
	}

	CaseStatement
	{
		Values: std::[std::[Expression]Dynamic]Vector;
		Body: std::[Statement]Dynamic;

		# is_default() INLINE BOOL := Values.empty();

		parse(p: Parser &) BOOL
		{
			IF(p.consume(:case))
			{
				DO(value: Expression *)
				{
					IF(!(value := Expression::parse(p)))
						p.fail("expected expression");
					Values += :gc(value);
				} WHILE(p.consume(:comma))
			} ELSE
				IF(!p.consume(:default))
					RETURN FALSE;

			p.expect(:colon);

			Body := :gc(Statement::parse_body(p));

			RETURN TRUE;
		}
	}

	BreakStatement -> Statement
	{
		Label: ControlLabel;
		# FINAL type() StatementType := StatementType::break;

		parse(p: Parser &) BOOL
		{
			IF(!p.consume(:break))
				RETURN FALSE;

			Label.parse(p);
			p.expect(:semicolon);
			RETURN TRUE;
		}
	}

	ContinueStatement -> Statement
	{
		Label: ControlLabel;
		# FINAL type() StatementType := StatementType::continue;

		parse(p: Parser &) BOOL
		{
			IF(!p.consume(:continue))
				RETURN FALSE;

			Label.parse(p);
			p.expect(:semicolon);
			RETURN TRUE;
		}
	}
}