INCLUDE "parser.rl"
INCLUDE "expression.rl"
INCLUDE "variable.rl"

INCLUDE 'std/vector'
INCLUDE 'std/memory'

::rlc::parser
{
	ENUM StatementType
	{
		block,
		if,
		variable,
		expression,
		return,
		try,
		catch
	}

	Statement
	{
		# ABSTRACT type() StatementType;

		STATIC parse(p: Parser&) Statement *
		{
			{
				v: BlockStatement;
				IF(v.parse(p))
					RETURN std::dup(__cpp_std::move(v));
			}

			{
				v: IfStatement;
				IF(v.parse(p))
					RETURN std::dup(__cpp_std::move(v));
			}

			{
				v: VariableStatement;
				IF(v.parse(p))
					RETURN std::dup(__cpp_std::move(v));
			}

			{
				v: ExpressionStatement;
				IF(v.parse(p))
					RETURN std::dup(__cpp_std::move(v));
			}

			{
				v: ReturnStatement;
				IF(v.parse(p))
					RETURN std::dup(__cpp_std::move(v));
			}

			{
				v: TryStatement;
				IF(v.parse(p))
					RETURN std::dup(__cpp_std::move(v));
			}

			RETURN NULL;
		}
	}

	::detail UNION VarOrExp
	{
		Variable: parser::LocalVariable *;
		Expression: parser::Expression *;
		# exists() INLINE bool := Variable != NULL;
	}
	VarOrExp
	{
		Value: detail::VarOrExp;
		IsVariable: bool;

		CONSTRUCTOR():
			IsVariable(FALSE)
		{
			Value.Expression := NULL;
		}

		CONSTRUCTOR(move: VarOrExp &&):
			IsVariable(move.IsVariable),
			Value(move.Value)
		{
			move.CONSTRUCTOR();
		}

		ASSIGN(move: VarOrExp &&) VarOrExp &
		{
			IF(&move != THIS)
			{
				THIS->DESTRUCTOR();
				THIS->CONSTRUCTOR(__cpp_std::move(move));
			}
			RETURN *THIS;
		}

		DESTRUCTOR
		{
			IF(IsVariable)
			{
				IF(Value.Variable)
					::delete(Value.Variable);
			} ELSE
				IF(Value.Expression)
					::delete(Value.Expression);
		}

		parse(p: Parser &) VOID
		{
			v: LocalVariable;
			IF(IsVariable := v.parse_var_decl(p))
				Value.Variable := std::dup(__cpp_std::move(v));
			ELSE IF(exp ::= Expression::parse(p))
				Value.Expression := exp;
			ELSE
				p.fail("expected variable or expression");
		}

		# exists() INLINE bool := Value.exists();
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

			IF(!(Then := Statement::parse(p)).Ptr)
				p.fail("expected statement");

			IF(p.consume(tok::Type::else))
			{
				IF(!(Else := Statement::parse(p)).Ptr)
					p.fail("expected statement");
			}

			RETURN TRUE;
		}
	}

	VariableStatement -> Statement
	{
		Variable: LocalVariable;

		# FINAL type() StatementType := StatementType::variable;

		parse(p: Parser &) bool
		{
			IF(!Variable.parse(p))
				RETURN FALSE;

			p.expect(tok::Type::semicolon);
			RETURN TRUE;
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

		# is_void() INLINE bool := Expression.Ptr == NULL;

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

		# has_finally() INLINE bool := Finally.Ptr != NULL;

		parse(p: Parser &) bool
		{
			IF(!p.consume(tok::Type::try))
				RETURN FALSE;

			IF(!(Body := Statement::parse(p)).Ptr)
				RETURN FALSE;

			FOR(catch: CatchStatement; catch.parse(p);)
				Catches.push_back(__cpp_std::move(catch));

			IF(p.consume(tok::Type::finally))
				IF(!(Finally := parser::Statement::parse(p)).Ptr)
					p.fail("expected statement");
			ELSE
				Finally := NULL;

			RETURN TRUE;
		}
	}

	CatchStatement -> Statement
	{
		IsVoid: bool;
		Exception: LocalVariable;
		Body: std::[Statement]Dynamic;

		# FINAL type() StatementType := StatementType::catch;

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

				IF(!Exception.parse(p))
					p.fail("expected variable");
			}
			p.expect(tok::Type::parentheseClose);

			IF(!(Body := Statement::parse(p)).Ptr)
				p.fail("expected statement");

			RETURN TRUE;
		}
	}
}