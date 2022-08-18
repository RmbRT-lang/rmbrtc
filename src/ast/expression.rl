INCLUDE "symbol.rl"
INCLUDE "type.rl"
INCLUDE "codeobject.rl"
INCLUDE "varorexpression.rl"
INCLUDE "exprorstatement.rl"
INCLUDE "typeorexpression.rl"
INCLUDE "statement.rl"

INCLUDE 'std/vector'

::rlc ENUM Operator
{
	add, sub, mul, div, mod,
	equals, notEquals, less, lessEquals, greater, greaterEquals, cmp,
	bitAnd, bitOr, bitXor, bitNot,
	logAnd, logOr, logNot,
	shiftLeft, shiftRight, rotateLeft, rotateRight,
	neg, pos,
	subscript, call, visit, reflectVisit, conditional,
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
	fork,
	await,
	expectDynamic,
	maybeDynamic,

	streamFeed,

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
		[Stage]VarOrExpr,
		[Stage]ExprOrStatement
	{
		Range: src::String;

		:transform{
			p: [Stage::Prev+]Expression #&,
			f: Stage::PrevFile+,
			s: Stage &
		} -> (p), (), (), ():
			Range := s.transform_string(p.Range, f);

		<<<
			p: [Stage::Prev+]Expression #&,
			f: Stage #&
		>>> [Stage]Expression-std::Dyn := Stage::transform_expression(p, f);
	}

	/// A statement evaluating into a value.
	[Stage: TYPE] StatementExpression VIRTUAL -> [Stage]Expression
	{
		Statement: ast::[Stage]Statement - std::Dyn;

		:transform{
			p: [Stage::Prev+]Expression #&,
			f: Stage::PrevFile+,
			s: Stage &
		} -> (:transform(p, f, s)):
			Statement := <<<ast::[Stage]Statement>>>(p.Statement!, f, s);
	}

	/// A reference to a variable, function, or constant.
	[Stage: TYPE] ReferenceExpression -> [Stage]Expression
	{
		Symbol: Stage::Symbol;

		:transform{
			p: [Stage::Prev+]ReferenceExpression #&,
			f: Stage::PrevFile+,
			s: Stage &
		} -> (:transform(p, f, s)):
			Symbol := s.tansform_symbol(p.Symbol, f);
	}

	/// A reference to an object's member variable, function, or constant.
	[Stage: TYPE] MemberReferenceExpression -> [Stage]Expression
	{
		Object: [Stage]Expression - std::Dyn;
		Member: Stage::MemberReference;
		IsArrowAccess: BOOL;

		:transform{
			p: [Stage::Prev+]MemberReferenceExpression #&,
			f: Stage::PrevFile+,
			s: Stage &
		} -> (:transform(p, f, s)):
			Object := <<<[Stage]Expression>>>(p.Object!, f, s),
			Member := s.transform_member_reference(p.Member, f),
			IsArrowAccess := p.IsArrowAccess;
	}

	/// A symbolic constant value.
	[Stage: TYPE] SymbolConstantExpression -> [Stage]Expression
	{
		Symbol: [Stage]SymbolConstant;

		:transform{
			p: [Stage::Prev+]SymbolConstantExpression #&,
			f: Stage::PrevFile+,
			s: Stage &
		} -> (:transform(p, f, s)):
			Symbol := :transform(p.Symbol, f, s);
	}

	/// A numeric expression.
	[Stage: TYPE] NumberExpression -> [Stage]Expression
	{
		Number: Stage::Number;

		:transform{
			p: [Stage::Prev+]NumberExpression #&,
			f: Stage::PrevFile+,
			s: Stage &
		} -> (:transform(p, f, s)):
			Number := s.transform_number(p.Number, f);
	}

	/// A boolean expression.
	[Stage: TYPE] BoolExpression -> [Stage]Expression
	{
		Value: BOOL;

		:transform{
			p: [Stage::Prev+]BoolExpression #&,
			f: Stage::PrevFile+,
			s: Stage &
		} -> (:transform(p, f, s)):
			Value := p.Value;
	}

	/// A character literal expression.
	[Stage: TYPE] CharExpression -> [Stage]Expression
	{
		Char: Stage::CharLiteral;

		:transform{
			p: [Stage::Prev+]CharExpression #&,
			f: Stage::PrevFile+,
			s: Stage &
		} -> (:transform(p, f, s)):
			Char := p.Char;
	}

	/// A string literal expression.
	[Stage: TYPE] StringExpression -> [Stage]Expression
	{
		String: Stage::StringLiteral;

		:transform{
			p: [Stage::Prev+]StringExpression #&,
			f: Stage::PrevFile+,
			s: Stage &
		} -> (:transform(p, f, s)):
			String := s.transform_string_literal(p.String, f);
	}

	(// Expression containing a user-overloadable operator. /)
	[Stage: TYPE] OperatorExpression -> [Stage]Expression
	{
		Operands: [Stage]Expression - std::DynVec;
		Op: rlc::Operator;

		:transform{
			p: [Stage::Prev+]OperatorExpression #&,
			f: Stage::PrevFile+,
			s: Stage &
		} -> (:transform(p, f, s)):
			Operands := :reserve(##p.Operands),
			Op := p.Op
		{
			FOR(o ::= p.Operands.start(); o; ++o)
				Operands += <<<[Stage]Expression>>>(o!, f, s);
		}

		STATIC make_unary(
			op: rlc::Operator,
			opPosition: src::Position,
			lhs: [Stage]Expression-std::Dyn
		) [Stage]Expression - std::Dyn
		{
			ret: OperatorExpression-std::Dyn := :a(BARE);
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
			ret: OperatorExpression-std::Dyn := :a(BARE);
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

		Method: Kind;
		Type: ast::[Stage]Type-std::Dyn;
		Values: [Stage]Expression - std::DynVec;

		:transform{
			p: [Stage::Prev+]CastExpression #&,
			f: Stage::PrevFile+,
			s: Stage &
		} -> (:transform(p, f, s)):
			Method := p.Method,
			Type := <<<ast::[Stage]Type>>>(p.Type!, f, s),
			Values := :reserve(##p.Values)
		{
			FOR(v ::= p.Values.start(); v; ++v)
				Values += <<<[Stage]Expression>>>(v!, f, s);
		}
	}

	/// `SIZEOF` expression.
	[Stage: TYPE] SizeofExpression -> [Stage]Expression
	{
		Term: [Stage]TypeOrExpr - std::Dyn;
		Variadic: BOOL;

		:transform{
			p: [Stage::Prev+]SizeofExpression #&,
			f: Stage::PrevFile+,
			s: Stage &
		} -> (:transform(p, f, s)):
			Term := <<<[Stage]TypeOrExpr>>>(p.Term!, f, s),
			Variadic := p.Variadic;
	}

	/// `TYPE`, `TYPE STATIC`, `TYPE TYPE` expressions.
	[Stage: TYPE] TypeofExpression -> [Stage]Expression
	{
		Term: [Stage]TypeOrExpr - std::Dyn;
		StaticExp: BOOL; // Only affects expressions.

		:transform{
			p: [Stage::Prev+]TypeofExpression #&,
			f: Stage::PrevFile+,
			s: Stage &
		} -> (:transform(p, f, s)):
			Term := <<<[Stage]TypeOrExpr>>>(p.Term!, f, s),
			StaticExp := p.StaticExp;
	}
}