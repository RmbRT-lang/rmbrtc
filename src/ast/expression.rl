INCLUDE "symbol.rl"
INCLUDE "type.rl"
INCLUDE "codeobject.rl"
INCLUDE "varorexpression.rl"
INCLUDE "typeorexpression.rl"
INCLUDE "statement.rl"
INCLUDE "stage.rl"

INCLUDE 'std/vector'

::rlc ENUM Operator
{
	add, sub, mul, div, mod,
	equals, notEquals, less, lessEquals, greater, greaterEquals, cmp,
	bitAnd, bitOr, bitXor, bitNot,
	logAnd, logOr, logNot,
	shiftLeft, shiftRight, rotateLeft, rotateRight,
	neg, pos,
	subscript, call, visit, conditional,
	memberReference, memberPointer, tupleMemberReference, tupleMemberPointer,
	bindReference, bindPointer,
	dereference, address, move,
	preIncrement, preDecrement,
	postIncrement, postDecrement,
	count,
	baseAddr,
	valueOf,

	async,
	fullAsync,
	await,
	expectDynamic,
	maybeDynamic,

	assign,
	addAssign, subAssign, mulAssign, divAssign, modAssign,
	bitAndAssign, bitOrAssign, bitXorAssign, bitNotAssign,
	logAndAssign, logOrAssign, logNotAssign,
	shiftLeftAssign, shiftRightAssign, rotateLeftAssign, rotateRightAssign,
	negAssign,

	tuple,
	variadicExpand,
	constructor,
	pointerConstructor,
	destructor,
	pointerDestructor
}

::rlc::ast
{
	(//
		Base type for all expressions.
		All expressions of the same compiler stage share the same base class.
	/)
	[Stage: TYPE] Expression VIRTUAL ->
		CodeObject,
		[Stage]TypeOrExpr,
		[Stage]VarOrExpr
	{
		Range: src::String;

		<<<
			prev: [Stage]PrevExpression,
			ctx: [Stage]Context
		>>> [Stage]Expression-std::Dyn := Stage::transform_expression(prev, ctx);
	}

	/// A statement evaluating into a value.
	[Stage: TYPE] StatementExpression VIRTUAL -> [Stage]Expression
	{
		Statement: ast::[Stage]Statement - std::Dyn;
	}

	/// A reference to a variable, function, or constant.
	[Stage: TYPE] ReferenceExpression -> [Stage]Expression
	{
		Symbol: Stage::Symbol;
	}

	/// A reference to an object's member variable, function, or constant.
	[Stage: TYPE] MemberReferenceExpression -> [Stage]Expression
	{
		Object: [Stage]Expression - std::Dyn;
		Member: Stage::MemberReference;
		IsArrowAccess: BOOL;
	}

	/// A symbolic constant value.
	[Stage: TYPE] SymbolConstantExpression -> [Stage]Expression
	{
		Symbol: [Stage]SymbolConstant;
	}

	/// A numeric expression.
	[Stage: TYPE] NumberExpression -> [Stage]Expression
	{
		Number: Stage::Number;
	}

	/// A boolean expression.
	[Stage: TYPE] BoolExpression -> [Stage]Expression
	{
		Value: BOOL;
	}

	/// A character literal expression.
	[Stage: TYPE] CharExpression -> [Stage]Expression
	{
		Char: Stage::CharLiteral;
	}

	/// A string literal expression.
	[Stage: TYPE] StringExpression -> [Stage]Expression
	{
		String: Stage::StringLiteral;
	}

	(// Expression containing a user-overloadable operator. /)
	[Stage: TYPE] OperatorExpression -> [Stage]Expression
	{
		Operands: [Stage]Expression - std::DynVec;
		Op: rlc::Operator;

		{}: Op(NOINIT);

		STATIC make_unary(
			op: rlc::Operator,
			opPosition: src::Position,
			lhs: [Stage]Expression-std::Dyn
		) [Stage]Expression - std::Dyn
		{
			ret: OperatorExpression-std::Dyn := :new();
			ret->Op := op;
			ret->Position := opPosition;
			ret->Range := lhs->Range;
			ret->Operands += &&lhs;
			= &&ret;
		}

		STATIC make_binary(
			op: rlc::Operator,
			opPosition: src::Position,
			lhs: [Stage]Expression - std::Dyn,
			rhs: [Stage]Expression - std::Dyn
		) [Stage]Expression - std::Dyn
		{
			ret: OperatorExpression-std::Dyn := :new();
			ret->Op := op;
			ret->Position := opPosition;
			ret->Range := lhs->Range.span(rhs->Range);
			ret->Operands += &&lhs;
			ret->Operands += &&rhs;
			= &&ret;
		}
	}

	/// `THIS` expression.
	[Stage: TYPE] ThisExpression -> [Stage]Expression { }

	/// `NULL` expression.
	[Stage: TYPE] NullExpression -> [Stage]Expression { }

	/// Static, dynamic, or factory cast expression.
	[Stage: TYPE] CastExpression -> [Stage]Expression
	{
		ENUM Kind { static, dynamic, mask }
		{}: Method(NOINIT);

		Method: Kind;
		Type: ast::[Stage]Type-std::Dyn;
		Values: [Stage]Expression - std::DynVec;
	}

	/// `SIZEOF` expression.
	[Stage: TYPE] SizeofExpression -> [Stage]Expression
	{
		Term: [Stage]TypeOrExpr - std::Dyn;
		Variadic: BOOL;
	}

	/// `TYPE`, `TYPE STATIC`, `TYPE TYPE` expressions.
	[Stage: TYPE] TypeofExpression -> [Stage]Expression
	{
		Term: [Stage]TypeOrExpr - std::Dyn;
		StaticExp: BOOL; // Only affects expressions.
	}
}