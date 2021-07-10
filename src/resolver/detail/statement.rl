INCLUDE "../statement.rl"
INCLUDE "../../util/dynunion.rl"
INCLUDE 'std/err/unimplemented'

::rlc::resolver::detail create_statement(
	stmt: scoper::Statement #\,
	cache: Cache &
) Statement \
{
	SWITCH(type ::= stmt->type())
	{
	DEFAULT:
		THROW <std::err::Unimplemented>(type.NAME());
	CASE :assert:
		RETURN std::[AssertStatement]new(<scoper::AssertStatement #\>(stmt));
	CASE :block:
		RETURN std::[BlockStatement]new(<scoper::BlockStatement #\>(stmt), cache);
	CASE :if:
		RETURN std::[IfStatement]new(<scoper::IfStatement #\>(stmt), cache);
	CASE :variable:
		RETURN std::[VariableStatement]new(<scoper::VariableStatement #\>(stmt), cache);
	CASE :expression:
		RETURN std::[ExpressionStatement]new(<scoper::ExpressionStatement #\>(stmt));
	CASE :return:
		RETURN std::[ReturnStatement]new(<scoper::ReturnStatement #\>(stmt));
	CASE :try:
		RETURN std::[TryStatement]new(<scoper::TryStatement #\>(stmt), cache);
	CASE :throw:
		RETURN std::[ThrowStatement]new(<scoper::ThrowStatement #\>(stmt));
	CASE :loop:
		RETURN std::[LoopStatement]new(<scoper::LoopStatement #\>(stmt), cache);
	CASE :switch:
		RETURN std::[SwitchStatement]new(<scoper::SwitchStatement #\>(stmt), cache);
	CASE :break:
		RETURN std::[BreakStatement]new(<scoper::BreakStatement #\>(stmt));
	CASE :continue:
		RETURN std::[ContinueStatement]new(<scoper::ContinueStatement #\>(stmt));
	}
}

::rlc::resolver
{
	VarOrExp
	{
		PRIVATE V: util::[LocalVariable; Expression]DynUnion;

		{};
		{:gc, v: LocalVariable \}: V(:gc(v));
		{:gc, v: Expression \}: V(:gc(v));
		{
			scope: scoper::Scope #\,
			v: scoper::VarOrExp #&,
			cache: Cache &
		}
		{
			IF(v.is_variable())
				V := :gc(std::[LocalVariable]new(v.variable(), cache));
			ELSE IF(v.is_expression())
				V := :gc(Expression::create(scope, v.expression()));
		}

		# is_variable() INLINE BOOL := V.is_first();
		# variable() INLINE LocalVariable \ := V.first();
		# is_expression() INLINE BOOL := V.is_second();
		# expression() INLINE Expression \ := V.second();
		# <BOOL> INLINE := V;

		[T:TYPE] THIS:=(v: T! &&) VarOrExp &
			:= std::help::custom_assign(THIS, <T!&&>(v));
	}

	AssertStatement -> Statement
	{
		# FINAL type() Statement::Type := :assert;

		Expression: resolver::Expression - std::Dynamic;

		{stmt: scoper::AssertStatement #\}
		->	Statement(stmt)
		:	Expression(:gc, resolver::Expression::create(stmt->ParentScope, stmt->Expression));
	}

	BlockStatement -> Statement
	{
		# FINAL type() Statement::Type := :block;

		Statements: Statement - std::Dynamic - std::Vector;

		{stmt: scoper::BlockStatement #\, cache: Cache &}
		->	Statement(stmt)
		{
			FOR(i ::= 0; i < ##stmt->Statements; i++)
				Statements += :gc(Statement::create(stmt->Statements[i], cache));
		}
	}

	IfStatement -> Statement
	{
		# FINAL type() Statement::Type := :if;

		Init: VarOrExp;
		Condition: VarOrExp;

		Then: std::[Statement]Dynamic;
		Else: std::[Statement]Dynamic;

		{stmt: scoper::IfStatement #\, cache: Cache &}
		->	Statement(stmt)
		:	Init(&stmt->InitScope, stmt->Init, cache),
			Condition(&stmt->CondScope, stmt->Condition, cache),
			Then(:gc(Statement::create(stmt->Then, cache)))
		{
			IF(stmt->Else)
				Else := :gc(Statement::create(stmt->Else, cache));
		}
	}

	VariableStatement -> Statement
	{
		# FINAL type() Statement::Type := :variable;

		Static: BOOL;
		Variable: LocalVariable;

		{stmt: scoper::VariableStatement #\, cache: Cache &}
		->	Statement(stmt)
		:	Static(stmt->Static),
			Variable(stmt->Variable, cache);
	}

	ExpressionStatement -> Statement
	{
		# FINAL type() Statement::Type := :expression;

		Expression: resolver::Expression - std::Dynamic;

		{stmt: scoper::ExpressionStatement #\}
		->	Statement(stmt)
		:	Expression(:gc(resolver::Expression::create(stmt->ParentScope, stmt->Expression)));
	}

	ReturnStatement -> Statement
	{
		# FINAL type() Statement::Type := :return;

		Expression: resolver::Expression - std::Dynamic;

		{stmt: scoper::ReturnStatement #\}
		->	Statement(stmt)
		{
			IF(stmt->Expression)
				Expression := :gc(resolver::Expression::create(stmt->ParentScope, stmt->Expression));
		}
	}

	TryStatement -> Statement
	{
		# FINAL type() Statement::Type := :try;

		Body: std::[Statement]Dynamic;
		Catches: std::[CatchStatement]Vector;
		Finally: std::[Statement]Dynamic;

		{stmt: scoper::TryStatement #\, cache: Cache&}
		->	Statement(stmt)
		:	Body(:gc(Statement::create(stmt->Body, cache)))
		{
			FOR(catch ::= stmt->Catches.start(); catch; ++catch)
				Catches += (*catch, cache);
			IF(stmt->Finally)
				Finally := :gc(Statement::create(stmt->Finally, cache));
		}
	}

	CatchStatement
	{
		Exception: LocalVariable;
		Body: std::[Statement]Dynamic;
		{catch: scoper::CatchStatement #&, cache: Cache &}:
			Exception(catch.Exception, cache),
			Body(:gc(Statement::create(catch.Body, cache)));
	}

	ThrowStatement -> Statement
	{
		# FINAL type() Statement::Type := :throw;

		TYPE Type := scoper::ThrowStatement::Type;

		ValueType: Type;
		Value: Expression - std::Dynamic;

		{stmt: scoper::ThrowStatement #\}
		->	Statement(stmt)
		:	ValueType(stmt->ValueType)
		{
			IF(stmt->Value)
				Value := :gc(Expression::create(stmt->ParentScope, stmt->Value));
		}
	}

	LoopStatement -> Statement
	{
		# FINAL type() Statement::Type := :loop;

		PostCondition: BOOL;
		Initial: VarOrExp;
		Condition: VarOrExp;
		Body: std::[Statement]Dynamic;
		PostLoop: std::[Expression]Dynamic;
		Label: scoper::ControlLabel;

		{stmt: scoper::LoopStatement #\, cache: Cache &}
		->	Statement(stmt)
		:	PostCondition(stmt->PostCondition),
			Initial(&stmt->InitScope, stmt->Initial, cache),
			Condition(&stmt->ConditionScope, stmt->Condition, cache),
			Body(:gc(Statement::create(stmt->Body, cache))),
			Label(stmt->Label)
		{
			IF(stmt->PostLoop)
				PostLoop := :gc(Expression::create(&stmt->ConditionScope, stmt->PostLoop));
		}
	}

	SwitchStatement -> Statement
	{
		# FINAL type() Statement::Type := :switch;

		Initial: VarOrExp;
		Value: VarOrExp;
		Cases: std::[CaseStatement]Vector;
		Label: scoper::ControlLabel;

		{stmt: scoper::SwitchStatement #\, cache: Cache &}
		->	Statement(stmt)
		:	Initial(&stmt->InitScope, stmt->Initial, cache),
			Value(&stmt->ValueScope, stmt->Value, cache),
			Label(stmt->Label)
		{
			FOR(case ::= stmt->Cases.start(); case; ++case)
				Cases += (*case, cache);
		}
	}

	CaseStatement
	{
		Values: std::[std::[Expression]Dynamic]Vector;
		Body: std::[Statement]Dynamic;

		# is_default() INLINE BOOL := Values.empty();

		{case: scoper::CaseStatement #&, cache: Cache &}:
			Body(:gc(Statement::create(case.Body, cache)))
		{
			FOR(value ::= case.Values.start(); value; ++value)
				Values += :gc(Expression::create(case.Body->ParentScope, *value));
		}
	}

	BreakStatement -> Statement
	{
		# FINAL type() Statement::Type := :break;

		Label: scoper::ControlLabel;

		{stmt: scoper::BreakStatement #\}
		->	Statement(stmt)
		:	Label(stmt->Label);

	}

	ContinueStatement -> Statement
	{
		# FINAL type() Statement::Type := :continue;

		Label: scoper::ControlLabel;

		{stmt: scoper::ContinueStatement #\}
		->	Statement(stmt)
		:	Label(stmt->Label);
	}
}