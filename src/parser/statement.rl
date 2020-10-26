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

		CONSTRUCTOR();
		CONSTRUCTOR(Statement &&);

		[T: TYPE]
		PRIVATE STATIC parse_impl(p: Parser &, out: Statement * &) bool
		{
			v: T;
			IF(v.parse(p))
			{
				out := std::dup_mv(v);
				RETURN TRUE;
			}
			RETURN FALSE;
		}

		STATIC parse(p: Parser&) Statement *
		{
			ret: Statement *;
			IF([BlockStatement]parse_impl(p, ret)
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

		parse(p: Parser &) bool
		{
			IF(!p.consume(tok::Type::assert))
				RETURN FALSE;

			p.expect(tok::Type::parentheseOpen);

			IF(!(Expression := parser::Expression::parse(p)))
				p.fail("expected expression");

			p.expect(tok::Type::parentheseClose);
			p.expect(tok::Type::semicolon);
			RETURN TRUE;
		}
	}

	VarOrExp
	{
		PRIVATE V: util::[LocalVariable, Expression]DynUnion;

		CONSTRUCTOR();
		CONSTRUCTOR(v: LocalVariable \): V(v);
		CONSTRUCTOR(v: Expression \): V(v);

		# is_variable() INLINE bool := V.is_first();
		# variable() INLINE LocalVariable \ := V.first();
		# is_expression() INLINE bool := V.is_second();
		# expression() INLINE Expression \ := V.second();
		# CONVERT(bool) INLINE NOTYPE! := V;

		[T:TYPE] ASSIGN(v: T! &&) VarOrExp &
			:= std::help::custom_assign(*THIS, __cpp_std::[T!]forward(v));

		parse(p: Parser &) VOID
		{
			IF(!parse_opt(p))
				p.fail("expected variable or expression");
		}

		parse_opt(p: Parser &) bool
		{
			v: std::[LocalVariable]Dynamic := [LocalVariable]new();
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

		parse(p: Parser&) bool
		{
			IF(!p.consume(tok::Type::braceOpen))
				RETURN FALSE;

			IF(p.consume(tok::Type::semicolon))
			{
				p.expect(tok::Type::braceClose);
				RETURN TRUE;
			}

			WHILE(!p.consume(tok::Type::braceClose))
			{
				IF(stmt ::= Statement::parse(p))
					Statements.push_back(stmt);
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

		parse(p: Parser &) bool
		{
			IF(!p.consume(tok::Type::if))
				RETURN FALSE;

			t: Trace(&p, "if statement");
			Label.parse(p);
			p.expect(tok::Type::parentheseOpen);

			val: VarOrExp;
			val.parse(p);

			IF(p.consume(tok::Type::semicolon))
			{
				Init := __cpp_std::move(val);
				val.parse(p);
			}

			Condition := __cpp_std::move(val);

			p.expect(tok::Type::parentheseClose);

			IF(!(Then := Statement::parse_body(p)).Ptr)
				p.fail("expected statement");

			IF(p.consume(tok::Type::else))
			{
				IF(!(Else := Statement::parse_body(p)).Ptr)
					p.fail("expected statement");
			}

			RETURN TRUE;
		}
	}

	VariableStatement -> Statement
	{
		Variable: LocalVariable;
		Static: bool;

		# FINAL type() StatementType := StatementType::variable;

		parse(p: Parser &) bool
		{
			Static := p.consume(tok::Type::static);
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

		parse(p: Parser &) bool
		{
			IF(!(Expression := parser::Expression::parse(p)).Ptr)
				RETURN FALSE;

			p.expect(tok::Type::semicolon);
			RETURN TRUE;
		}
	}

	ReturnStatement -> Statement
	{
		Expression: std::[parser::Expression]Dynamic;

		# FINAL type() StatementType := StatementType::return;

		# is_void() INLINE bool := !Expression;

		parse(p: Parser &) bool
		{
			IF(!p.consume(tok::Type::return))
				RETURN FALSE;

			Expression := parser::Expression::parse(p);

			p.expect(tok::Type::semicolon);

			RETURN TRUE;
		}
	}

	TryStatement -> Statement
	{
		Body: std::[Statement]Dynamic;
		Catches: std::[CatchStatement]Vector;
		Finally: std::[Statement]Dynamic;

		# FINAL type() StatementType := StatementType::try;

		# has_finally() INLINE bool := Finally;

		parse(p: Parser &) bool
		{
			IF(!p.consume(tok::Type::try))
				RETURN FALSE;

			IF(!(Body := Statement::parse_body(p)).Ptr)
				RETURN FALSE;

			FOR(catch: CatchStatement; catch.parse(p);)
				Catches.push_back(__cpp_std::move(catch));

			IF(p.consume(tok::Type::finally))
				IF(!(Finally := parser::Statement::parse_body(p)).Ptr)
					p.fail("expected statement");
			ELSE
				Finally := NULL;

			RETURN TRUE;
		}
	}

	CatchStatement
	{
		IsVoid: bool;
		Exception: LocalVariable;
		Body: std::[Statement]Dynamic;

		parse(p: Parser &) bool
		{
			IF(!p.consume(tok::Type::catch))
				RETURN FALSE;

			t: Trace(&p, "catch clause");

			p.expect(tok::Type::parentheseOpen);
			IF(p.match(tok::Type::parentheseClose)
			|| (p.match(tok::Type::void)
				&& p.match_ahead(tok::Type::parentheseClose)))
			{
				IsVoid := TRUE;
			} ELSE
			{
				IsVoid := FALSE;

				IF(!Exception.parse(p, FALSE))
					p.fail("expected variable");
			}
			p.expect(tok::Type::parentheseClose);

			IF(!(Body := Statement::parse_body(p)).Ptr)
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

		parse(p: Parser &) bool
		{
			IF(!p.consume(tok::Type::throw))
				RETURN FALSE;

			IF(p.consume(tok::Type::tripleDot))
				ValueType := Type::rethrow;
			ELSE IF(p.match(tok::Type::semicolon))
				ValueType := Type::void;
			ELSE
				IF((Value := Expression::parse(p)).Ptr)
					ValueType := Type::value;
				ELSE
					p.fail("expected expression");

			p.expect(tok::Type::semicolon);

			RETURN TRUE;
		}
	}

	LoopStatement -> Statement
	{
		IsPostCondition: bool;
		Initial: VarOrExp;
		Condition: VarOrExp;
		Body: std::[Statement]Dynamic;
		PostLoop: std::[Expression]Dynamic;
		Label: ControlLabel;

		# FINAL type() StatementType := StatementType::loop;

		parse(p: Parser &) bool
		{
			IF(!p.match(tok::Type::do)
			&& !p.match(tok::Type::for)
			&& !p.match(tok::Type::while))
				RETURN FALSE;

			parse_loop_head(p);

			IF(!(Body := Statement::parse_body(p)).Ptr)
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

		parse_do_head(p: Parser &) bool
		{
			IF(!p.consume(tok::Type::do))
				RETURN FALSE;

			IsPostCondition := TRUE;

			Label.parse(p);
			p.expect(tok::Type::parentheseOpen);
			parse_initial(p);
			p.expect(tok::Type::parentheseClose);

			RETURN TRUE;
		}

		parse_for_head(p: Parser &) bool
		{
			IF(!p.consume(tok::Type::for))
				RETURN FALSE;

			IF(!IsPostCondition)
				Label.parse(p);
			p.expect(tok::Type::parentheseOpen);

			IF(!IsPostCondition)
			{
				parse_initial(p);
				p.expect(tok::Type::semicolon);
			}

			IF(!p.consume(tok::Type::semicolon))
			{
				parse_condition(p);
				p.expect(tok::Type::semicolon);
			}

			PostLoop := Expression::parse(p);

			p.expect(tok::Type::parentheseClose);
			RETURN TRUE;
		}

		parse_while_head(p: Parser &) bool
		{
			IF(!p.consume(tok::Type::while))
				RETURN FALSE;

			IF(!IsPostCondition)
				Label.parse(p);
			p.expect(tok::Type::parentheseOpen);

			IF(!IsPostCondition)
			{
				v: VarOrExp;
				v.parse(p);
				IF(p.consume(tok::Type::semicolon))
				{
					Initial := __cpp_std::move(v);
					v.parse(p);
				}

				Condition := __cpp_std::move(v);
			} ELSE
			{
				IF(!(Condition := Expression::parse(p)))
					p.fail("expected expression");
			}

			p.expect(tok::Type::parentheseClose);
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

		parse(p: Parser &) bool
		{
			IF(!p.consume(tok::Type::switch))
				RETURN FALSE;

			Label.parse(p);
			p.expect(tok::Type::parentheseOpen);

			val: VarOrExp;
			val.parse(p);

			IF(p.consume(tok::Type::semicolon))
			{
				Initial := __cpp_std::move(val);
				Value.parse(p);
			} ELSE
				Value := __cpp_std::move(val);

			p.expect(tok::Type::parentheseClose);
			p.expect(tok::Type::braceOpen);

			DO(case: CaseStatement)
			{
				IF(!case.parse(p))
					p.fail("expected case");

				Cases.push_back(__cpp_std::move(case));
			} WHILE(!p.consume(tok::Type::braceClose))

			RETURN TRUE;
		}
	}

	CaseStatement
	{
		Values: std::[std::[Expression]Dynamic]Vector;
		Body: std::[Statement]Dynamic;

		# is_default() INLINE bool := Values.empty();

		parse(p: Parser &) bool
		{
			IF(p.consume(tok::Type::case))
			{
				DO(value: Expression *)
				{
					IF(!(value := Expression::parse(p)))
						p.fail("expected expression");
					Values.push_back(value);
				} WHILE(p.consume(tok::Type::comma))
			} ELSE
				IF(!p.consume(tok::Type::default))
					RETURN FALSE;

			p.expect(tok::Type::colon);

			Body := Statement::parse_body(p);

			RETURN TRUE;
		}
	}

	BreakStatement -> Statement
	{
		Label: ControlLabel;
		# FINAL type() StatementType := StatementType::break;

		parse(p: Parser &) bool
		{
			IF(!p.consume(tok::Type::break))
				RETURN FALSE;

			Label.parse(p);
			p.expect(tok::Type::semicolon);
			RETURN TRUE;
		}
	}

	ContinueStatement -> Statement
	{
		Label: ControlLabel;
		# FINAL type() StatementType := StatementType::continue;

		parse(p: Parser &) bool
		{
			IF(!p.consume(tok::Type::continue))
				RETURN FALSE;

			Label.parse(p);
			p.expect(tok::Type::semicolon);
			RETURN TRUE;
		}
	}
}