INCLUDE "expression.rl"
INCLUDE "variable.rl"
INCLUDE "controllabel.rl"

INCLUDE 'std/vector'
INCLUDE 'std/memory'

::rlc::ast
{
	[Stage: TYPE] Statement VIRTUAL
	{
	}

	[Stage: TYPE] AssertStatement -> [Stage]Statement
	{
		Expression: ast::[Stage]Expression - std::Dyn;
	}

	[Stage: TYPE] BlockStatement -> [Stage]Statement
	{
		Statements: [Stage]Statement - std::DynVec;
	}

	[Stage: TYPE] IfStatement -> [Stage]Statement
	{
		Label: [Stage]ControlLabel;

		Init: [Stage]VarOrExpr-std::Dyn;
		Condition: [Stage]VarOrExpr-std::Dyn;

		Then: [Stage]Statement - std::Dyn;
		Else: [Stage]Statement - std::Dyn;
	}

	[Stage: TYPE] VariableStatement -> [Stage]Statement
	{
		Variable: [Stage]LocalVariable;
		Static: BOOL;
	}

	[Stage: TYPE] ExpressionStatement -> [Stage]Statement
	{
		Expression: ast::[Stage]Expression - std::Dyn;
	}

	[Stage: TYPE] ReturnStatement -> [Stage]Statement
	{
		Expression: ast::[Stage]Expression - std::Dyn;

		{};

		:exp{
			e: ast::[Stage]Expression - std::Dyn
		}:	Expression(&&e);

		# is_void() INLINE BOOL := !Expression;
	}

	[Stage: TYPE] TryStatement -> [Stage]Statement
	{
		Body: [Stage]Statement - std::Dyn;
		Catches: [Stage]CatchStatement - std::Vec;
		Finally: [Stage]Statement - std::Dyn;

		# has_finally() INLINE BOOL := Finally;
	}

	[Stage: TYPE] CatchStatement
	{
		ENUM Type
		{
			void,
			any,
			specific
		}

		ExceptionType: Type;
		Exception: [Stage]TypeOrCatchVariable - std::Dyn;
		Body: [Stage]Statement - std::Dyn;
	}

	[Stage: TYPE] ThrowStatement -> [Stage]Statement
	{
		ENUM Type
		{
			rethrow,
			void,
			value
		}

		ValueType: Type;
		Value: [Stage]Expression-std::Dyn;
	}

	[Stage: TYPE] LoopStatement -> [Stage]Statement
	{
		IsPostCondition: BOOL;
		Initial: [Stage]VarOrExpr - std::Dyn;
		Condition: [Stage]VarOrExpr - std::Dyn;
		Body: [Stage]Statement-std::Dyn;
		PostLoop: [Stage]Expression-std::Dyn;
		Label: [Stage]ControlLabel;
	}

	[Stage: TYPE] SwitchStatement -> [Stage]Statement
	{
		Initial: [Stage]VarOrExpr - std::Dyn;
		Value: [Stage]VarOrExpr - std::Dyn;
		Cases: [Stage]CaseStatement - std::Vec;
		Label: [Stage]ControlLabel;
	}

	[Stage: TYPE] CaseStatement
	{
		Values: [Stage]Expression - std::DynVec;
		Body: [Stage]Statement-std::Dyn;

		# is_default() INLINE BOOL := Values.empty();
	}

	[Stage: TYPE] TypeSwitchStatement -> [Stage]Statement
	{
		Static: BOOL;
		Initial: [Stage]VarOrExpr - std::Dyn;
		Value: [Stage]VarOrExpr - std::Dyn;
		Cases: [Stage]TypeCaseStatement - std::Vec;
		Label: [Stage]ControlLabel;
	}

	[Stage: TYPE] TypeCaseStatement
	{
		Types: [Stage]Type - std::DynVec;
		Body: [Stage]Statement-std::Dyn;

		# is_default() INLINE BOOL := Types.empty();
	}

	[Stage: TYPE] BreakStatement -> [Stage]Statement
	{
		Label: [Stage]ControlLabel;
	}

	[Stage: TYPE] ContinueStatement -> [Stage]Statement
	{
		Label: [Stage]ControlLabel;
	}
}