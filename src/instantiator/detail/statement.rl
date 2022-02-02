INCLUDE "../statement.rl"
INCLUDE "../variable.rl"
INCLUDE "../../util/dynunion.rl"
INCLUDE 'std/err/unimplemented'

::rlc::instantiator::detail create_statement(
	stmt: resolver::Statement #\,
	scope: VOID*
) Statement \
{
	THROW;
	(/
	TYPE SWITCH(stmt)
	{
	DEFAULT:
		THROW <std::err::Unimplemented>(TYPE(stmt));
	resolver::AssertStatement:
		RETURN std::[AssertStatement]new(<<resolver::AssertStatement #\>>(stmt), scope);
	resolver::BlockStatement:
		RETURN std::[BlockStatement]new(<<resolver::BlockStatement #\>>(stmt), scope);
	resolver::IfStatement:
		RETURN std::[IfStatement]new(<<resolver::IfStatement #\>>(stmt), scope);
	resolver::VariableStatement:
		RETURN std::[VariableStatement]new(<<resolver::VariableStatement #\>>(stmt), scope);
	resolver::ExpressionStatement:
		RETURN std::[ExpressionStatement]new(<<resolver::ExpressionStatement #\>>(stmt), scope);
	resolver::ReturnStatement:
		RETURN std::[ReturnStatement]new(<<resolver::ReturnStatement #\>>(stmt), scope);
	resolver::TryStatement:
		RETURN std::[TryStatement]new(<<resolver::TryStatement #\>>(stmt), scope);
	resolver::ThrowStatement:
		RETURN std::[ThrowStatement]new(<<resolver::ThrowStatement #\>>(stmt), scope);
	resolver::LoopStatement:
		RETURN std::[LoopStatement]new(<<resolver::LoopStatement #\>>(stmt), scope);
	resolver::SwitchStatement:
		RETURN std::[SwitchStatement]new(<<resolver::SwitchStatement #\>>(stmt), scope);
	resolver::TypeSwitchStatement:
		RETURN std::[TypeSwitchStatement]new(<<resolver::TypeSwitchStatement #\>>(stmt), scope);
	resolver::BreakStatement:
		RETURN std::[BreakStatement]new(<<resolver::BreakStatement #\>>(stmt), scope);
	resolver::ContinueStatement:
		RETURN std::[ContinueStatement]new(<<resolver::ContinueStatement# \>>(stmt), scope);
	}/)
}

::rlc::instantiator
{
	VarOrExp
	{
		PRIVATE V: util::[LocalVariable; Expression]DynUnion;

		{};
		{:gc, v: LocalVariable \}: V(:gc(v));
		{:gc, v: Expression \}: V(:gc(v));
		{
			v: resolver::VarOrExp #&,
			scope: Scope &
		}
		{
			IF(v.is_variable())
				V := :gc(std::[LocalVariable]new(v.variable(), scope));
			ELSE IF(v.is_expression())
				V := :gc(<<<Expression>>>(v.expression(), scope));
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
		Expression: instantiator::Expression - std::Dynamic;
	}

	BlockStatement -> Statement
	{
		Statements: Statement - std::DynVector;
	}

	IfStatement -> Statement
	{
		Init: VarOrExp;
		Condition: VarOrExp;

		Then: Statement - std::Dynamic;
		Else: Statement - std::Dynamic;
	}

	VariableStatement -> Statement
	{
		Static: BOOL;
		Variable: LocalVariable;
	}

	ExpressionStatement -> Statement
	{
		Expression: instantiator::Expression - std::Dynamic;
	}

	ReturnStatement -> Statement
	{
		Expression: instantiator::Expression - std::Dynamic;
	}

	TryStatement -> Statement
	{
		Body: Statement - std::Dynamic;
		Catches: CatchStatement - std::Vector;
		Finally: Statement - std::Dynamic;
	}

	CatchStatement
	{
		Exception: LocalVariable;
		Body: Statement - std::Dynamic;
	}

	ThrowStatement -> Statement
	{
		TYPE Type := resolver::ThrowStatement::Type;
		ValueType: Type;
		Value: Expression - std::Dynamic;
	}

	LoopStatement -> Statement
	{
		PostCondition: BOOL;
		Initial: VarOrExp;
		Condition: VarOrExp;
		Body: Statement - std::Dynamic;
		PostLoop: Expression - std::Dynamic;
		Label: scoper::ControlLabel;
	}

	SwitchStatement -> Statement
	{
		Initial: VarOrExp;
		Value: VarOrExp;
		Cases: CaseStatement - std::Vector;
		Label: scoper::ControlLabel;
	}

	CaseStatement
	{
		Values: Expression - std::DynVector;
		Body: Statement - std::Dynamic;
	}

	TypeSwitchStatement -> Statement
	{
		Static: BOOL;
		Initial: VarOrExp;
		Value: VarOrExp;
		Cases: TypeCaseStatement - std::Vector;
		Label: scoper::ControlLabel;
	}

	TypeCaseStatement
	{
		Values: Expression - std::DynVector;
		Body: Statement - std::Dynamic;
	}

	BreakStatement -> Statement
	{
		Label: scoper::ControlLabel;
	}

	ContinueStatement -> Statement
	{
		Label: scoper::ControlLabel;
	}
}