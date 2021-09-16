INCLUDE "../statement.rl"
INCLUDE "../../util/dynunion.rl"
INCLUDE 'std/err/unimplemented'

::rlc::resolver::detail create_statement(
	stmt: scoper::Statement #\,
	cache: Cache &
) Statement \
{
	TYPE SWITCH(stmt)
	{
	DEFAULT:
		THROW <std::err::Unimplemented>(TYPE(stmt));
	CASE scoper::AssertStatement:
		RETURN std::[AssertStatement]new(<scoper::AssertStatement #\>(stmt));
	CASE scoper::BlockStatement:
		RETURN std::[BlockStatement]new(<scoper::BlockStatement #\>(stmt), cache);
	CASE scoper::IfStatement:
		RETURN std::[IfStatement]new(<scoper::IfStatement #\>(stmt), cache);
	CASE scoper::VariableStatement:
		RETURN std::[VariableStatement]new(<scoper::VariableStatement #\>(stmt), cache);
	CASE scoper::ExpressionStatement:
		RETURN std::[ExpressionStatement]new(<scoper::ExpressionStatement #\>(stmt));
	CASE scoper::ReturnStatement:
		RETURN std::[ReturnStatement]new(<scoper::ReturnStatement #\>(stmt));
	CASE scoper::TryStatement:
		RETURN std::[TryStatement]new(<scoper::TryStatement #\>(stmt), cache);
	CASE scoper::ThrowStatement:
		RETURN std::[ThrowStatement]new(<scoper::ThrowStatement #\>(stmt));
	CASE scoper::LoopStatement:
		RETURN std::[LoopStatement]new(<scoper::LoopStatement #\>(stmt), cache);
	CASE scoper::SwitchStatement:
		RETURN std::[SwitchStatement]new(<scoper::SwitchStatement #\>(stmt), cache);
	CASE scoper::TypeSwitchStatement:
		RETURN std::[TypeSwitchStatement]new(<scoper::TypeSwitchStatement #\>(stmt), cache);
	CASE scoper::BreakStatement:
		RETURN std::[BreakStatement]new(<scoper::BreakStatement #\>(stmt));
	CASE scoper::ContinueStatement:
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
				V := :gc(<<<Expression>>>(scope, v.expression()));
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
		Expression: resolver::Expression - std::Dynamic;

		{stmt: scoper::AssertStatement #\}
		->	Statement(stmt)
		:	Expression(:gc, <<<resolver::Expression>>>(stmt->ParentScope, stmt->Expression));
	}

	BlockStatement -> Statement
	{
		Statements: Statement - std::DynVector;

		{stmt: scoper::BlockStatement #\, cache: Cache &}
		->	Statement(stmt)
		{
			FOR(i ::= 0; i < ##stmt->Statements; i++)
				Statements += :gc(<<<Statement>>>(stmt->Statements[i], cache));
		}
	}

	IfStatement -> Statement
	{
		Init: VarOrExp;
		Condition: VarOrExp;

		Then: std::[Statement]Dynamic;
		Else: std::[Statement]Dynamic;

		{stmt: scoper::IfStatement #\, cache: Cache &}
		->	Statement(stmt)
		:	Init(&stmt->InitScope, stmt->Init, cache),
			Condition(&stmt->CondScope, stmt->Condition, cache),
			Then(:gc(<<<Statement>>>(stmt->Then, cache)))
		{
			IF(stmt->Else)
				Else := :gc(<<<Statement>>>(stmt->Else, cache));
		}
	}

	VariableStatement -> Statement
	{
		Static: BOOL;
		Variable: LocalVariable;

		{stmt: scoper::VariableStatement #\, cache: Cache &}
		->	Statement(stmt)
		:	Static(stmt->Static),
			Variable(stmt->Variable, cache);
	}

	ExpressionStatement -> Statement
	{
		Expression: resolver::Expression - std::Dynamic;

		{stmt: scoper::ExpressionStatement #\}
		->	Statement(stmt)
		:	Expression(:gc(<<<resolver::Expression>>>(stmt->ParentScope, stmt->Expression)));
	}

	ReturnStatement -> Statement
	{
		Expression: resolver::Expression - std::Dynamic;

		{stmt: scoper::ReturnStatement #\}
		->	Statement(stmt)
		{
			IF(stmt->Expression)
				Expression := :gc(<<<resolver::Expression>>>(stmt->ParentScope, stmt->Expression));
		}
	}

	TryStatement -> Statement
	{
		Body: std::[Statement]Dynamic;
		Catches: std::[CatchStatement]Vector;
		Finally: std::[Statement]Dynamic;

		{stmt: scoper::TryStatement #\, cache: Cache&}
		->	Statement(stmt)
		:	Body(:gc(<<<Statement>>>(stmt->Body, cache)))
		{
			FOR(catch ::= stmt->Catches.start(); catch; ++catch)
				Catches += (catch!, cache);
			IF(stmt->Finally)
				Finally := :gc(<<<Statement>>>(stmt->Finally, cache));
		}
	}

	CatchStatement
	{
		Exception: LocalVariable;
		Body: std::[Statement]Dynamic;
		{catch: scoper::CatchStatement #&, cache: Cache &}:
			Exception(catch.Exception, cache),
			Body(:gc(<<<Statement>>>(catch.Body, cache)));
	}

	ThrowStatement -> Statement
	{
		TYPE Type := scoper::ThrowStatement::Type;

		ValueType: Type;
		Value: Expression - std::Dynamic;

		{stmt: scoper::ThrowStatement #\}
		->	Statement(stmt)
		:	ValueType(stmt->ValueType)
		{
			IF(stmt->Value)
				Value := :gc(<<<Expression>>>(stmt->ParentScope, stmt->Value));
		}
	}

	LoopStatement -> Statement
	{
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
			Body(:gc(<<<Statement>>>(stmt->Body, cache))),
			Label(stmt->Label)
		{
			IF(stmt->PostLoop)
				PostLoop := :gc(<<<Expression>>>(&stmt->ConditionScope, stmt->PostLoop));
		}
	}

	SwitchStatement -> Statement
	{
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
				Cases += (case!, cache);
		}
	}

	CaseStatement
	{
		Values: Expression - std::DynVector;
		Body: std::[Statement]Dynamic;

		# is_default() INLINE BOOL := Values.empty();

		{case: scoper::CaseStatement #&, cache: Cache &}:
			Body(:gc(<<<Statement>>>(case.Body, cache)))
		{
			FOR(value ::= case.Values.start(); value; ++value)
				Values += :gc(<<<Expression>>>(case.Body->ParentScope, value!));
		}
	}

	TypeSwitchStatement -> Statement
	{
		Static: BOOL;
		Initial: VarOrExp;
		Value: VarOrExp;
		Cases: std::[TypeCaseStatement]Vector;
		Label: scoper::ControlLabel;

		{stmt: scoper::TypeSwitchStatement #\, cache: Cache &}
		->	Statement(stmt)
		:	Static(stmt->Static),
			Initial(&stmt->InitScope, stmt->Initial, cache),
			Value(&stmt->ValueScope, stmt->Value, cache),
			Label(stmt->Label)
		{
			FOR(case ::= stmt->Cases.start(); case; ++case)
				Cases += (case!, cache);
		}
	}

	TypeCaseStatement
	{
		Types: Type - std::DynVector;
		Body: std::[Statement]Dynamic;

		# is_default() INLINE BOOL := Types.empty();

		{case: scoper::TypeCaseStatement #&, cache: Cache &}:
			Body(:gc(<<<Statement>>>(case.Body, cache)))
		{
			FOR(type ::= case.Types.start(); type; ++type)
				Types += :gc(<<<Type>>>(case.Body->ParentScope, type!));
		}
	}

	BreakStatement -> Statement
	{
		Label: scoper::ControlLabel;

		{stmt: scoper::BreakStatement #\}
		->	Statement(stmt)
		:	Label(stmt->Label);

	}

	ContinueStatement -> Statement
	{
		Label: scoper::ControlLabel;

		{stmt: scoper::ContinueStatement #\}
		->	Statement(stmt)
		:	Label(stmt->Label);
	}
}