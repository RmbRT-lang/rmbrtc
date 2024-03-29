INCLUDE "symbol.rl"
INCLUDE "type.rl"
INCLUDE "codeobject.rl"
INCLUDE "varorexpression.rl"
INCLUDE "exprorstatement.rl"
INCLUDE "typeorexpression.rl"
INCLUDE "statement.rl"

INCLUDE 'std/vector'
INCLUDE 'std/value'

::rlc ENUM Operator
{
	add, sub, mul, div, mod,
	equals, notEquals, less, lessEquals, greater, greaterEquals, cmp,
	bitAnd, bitOr, bitXor, bitNot,
	logAnd, logOr, logNot,
	natAnd, natOr,
	shiftLeft, shiftRight, rotateLeft, rotateRight,
	neg, pos,
	subscript, call, visit, reflectVisit, conditional,
	memberReference, memberPointer, tupleMemberReference, tupleMemberPointer,
	bindReference, bindPointer,
	dereference, address, move,
	preIncrement, preDecrement,
	postIncrement, postDecrement,
	count,
	structure,
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

	concretise,

	tuple,
	variadicExpand,
	constructor,
	virtualConstructor,
	pointerConstructor,
	virtualPointerConstructor,
	destructor,
	pointerDestructor,
	copyRtti
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
		/// For local variable lookup.
		LocalPos: LocalPosition;

		/// Number of variables this expression declares.
		# VIRTUAL variables() LocalCount := 0;

		:at {
			x: THIS #&
		} -> (x), (), (), ():
			LocalPos := x.LocalPos,
			Range := x.Range;

		:transform {
			p: [Stage::Prev+]Expression #&,
			ctx: Stage::Context+ #&
		} -> (p), (), (), ():
			LocalPos := p.LocalPos,
			Range := p.Range;

		<<<
			p: [Stage::Prev+]Expression #&,
			ctx: Stage::Context+ #&
		>>> THIS-std::Val
		{
			TYPE SWITCH(p)
			{
			[Stage::Prev+]StatementExpression:
				= :a.[Stage]StatementExpression(:transform(>>p!, ctx));
			[Stage::Prev+]ReferenceExpression:
				= :a.[Stage]ReferenceExpression(:transform(>>p!, ctx));
			[Stage::Prev+]MemberReferenceExpression:
				= :a.[Stage]MemberReferenceExpression(:transform(>>p!, ctx));
			[Stage::Prev+]SymbolConstantExpression:
				= :a.[Stage]SymbolConstantExpression(:transform(>>p!, ctx));
			[Stage::Prev+]NumberExpression:
				= :a.[Stage]NumberExpression(:transform(>>p!, ctx));
			[Stage::Prev+]BoolExpression:
				= :a.[Stage]BoolExpression(:transform(>>p!, ctx));
			[Stage::Prev+]CharExpression:
				= :a.[Stage]CharExpression(:transform(>>p!, ctx));
			[Stage::Prev+]StringExpression:
				= :a.[Stage]StringExpression(:transform(>>p!, ctx));
			[Stage::Prev+]OperatorExpression:
				= :a.[Stage]OperatorExpression(:transform(>>p!, ctx));
			[Stage::Prev+]ThisExpression:
				= :a.[Stage]ThisExpression(:transform(>>p!, ctx));
			[Stage::Prev+]NullExpression:
				= :a.[Stage]NullExpression(:transform(>>p!, ctx));
			[Stage::Prev+]BareExpression:
				= :a.[Stage]BareExpression(:transform(>>p!, ctx));
			[Stage::Prev+]CastExpression:
				= :a.[Stage]CastExpression(:transform(>>p!, ctx));
			[Stage::Prev+]SizeofExpression:
				= :a.[Stage]SizeofExpression(:transform(>>p!, ctx));
			[Stage::Prev+]TypeofExpression:
				= :a.[Stage]TypeofExpression(:transform(>>p!, ctx));
			[Stage::Prev+]CopyRttiExpression:
				= :a.[Stage]CopyRttiExpression(:transform(>>p!, ctx));
			[Stage::Prev+]BaseExpression:
				= :a.[Stage]BaseExpression(:transform(>>p!, ctx));
			}

			DIE;
		}

		PRIVATE # FINAL cmp_typeorexpr_impl(rhs: [Stage]TypeOrExpr#&) S1
		{
			DIE "attempted to compare two expressions!";
		}
	}

	/// A statement evaluating into a value.
	[Stage: TYPE] StatementExpression -> [Stage]Expression
	{
		Statement: ast::[Stage]Statement - std::Val;

		:transform{
			p: [Stage::Prev+]StatementExpression #&,
			ctx: Stage::Context+ #&
		} -> (:transform, p, ctx):
			Statement := :make(p.Statement!, ctx);
	}

	/// A reference to a variable, function, or constant.
	[Stage: TYPE] ReferenceExpression -> [Stage]Expression
	{
		Symbol: Stage::Symbol;
		:transform{
			p: [Stage::Prev+]ReferenceExpression #&,
			ctx: Stage::Context+ #&
		} -> (:transform, p, ctx):
			Symbol := ctx.transform_symbol(p.Symbol, THIS.LocalPos);
	}

	/// A reference to an object's member variable, function, or constant.
	[Stage: TYPE] MemberReferenceExpression -> [Stage]Expression
	{
		Object: [Stage]Expression - std::Val;
		Member: Stage::MemberReference;
		IsArrowAccess: BOOL;

		:transform{
			p: [Stage::Prev+]MemberReferenceExpression #&,
			ctx: Stage::Context+ #&
		} -> (:transform, p, ctx):
			Object := :make(p.Object!, ctx),
			Member := ctx.transform_member_reference(p.Member),
			IsArrowAccess := p.IsArrowAccess;
	}

	/// A symbolic constant value.
	[Stage: TYPE] SymbolConstantExpression -> [Stage]Expression
	{
		Symbol: [Stage]SymbolConstant;

		:transform{
			p: [Stage::Prev+]SymbolConstantExpression #&,
			ctx: Stage::Context+ #&
		} -> (:transform, p, ctx):
			Symbol := :transform(p.Symbol, ctx);
	}

	/// A numeric expression.
	[Stage: TYPE] NumberExpression -> [Stage]Expression
	{
		Number: Stage::Number;

		:transform{
			p: [Stage::Prev+]NumberExpression #&,
			ctx: Stage::Context+ #&
		} -> (:transform, p, ctx):
			Number := ctx.transform_number(p.Number);
	}

	/// A boolean expression.
	[Stage: TYPE] BoolExpression -> [Stage]Expression
	{
		Value: BOOL;

		:transform{
			p: [Stage::Prev+]BoolExpression #&,
			ctx: Stage::Context+ #&
		} -> (:transform, p, ctx):
			Value := p.Value;
	}

	/// A character literal expression.
	[Stage: TYPE] CharExpression -> [Stage]Expression
	{
		Char: Stage::CharLiteral;

		:transform{
			p: [Stage::Prev+]CharExpression #&,
			ctx: Stage::Context+ #&
		} -> (:transform, p, ctx):
			Char := ctx.transform_char_literal(p.Char);
	}

	/// A string literal expression.
	[Stage: TYPE] StringExpression -> [Stage]Expression
	{
		String: Stage::StringLiteral;

		:transform{
			p: [Stage::Prev+]StringExpression #&,
			ctx: Stage::Context+ #&
		} -> (:transform, p, ctx):
			String := ctx.transform_string_literal(p.String!);
	}

	(// Expression containing a user-overloadable operator. /)
	[Stage: TYPE] OperatorExpression -> [Stage]Expression
	{
		Operands: [Stage]Expression - std::ValVec;
		Op: rlc::Operator;

		:transform{
			p: [Stage::Prev+]OperatorExpression #&,
			ctx: Stage::Context+ #&
		} -> (:transform, p, ctx):
			Operands := :reserve(##p.Operands),
			Op := p.Op
		{
			FOR(o ::= p.Operands.start())
				Operands += :make(o!, ctx);
		}

		STATIC make_unary(
			op: rlc::Operator,
			opPosition: src::Position,
			lhs: [Stage]Expression-std::Val
		) [Stage]Expression - std::Val
		{
			ret: OperatorExpression-std::Val := :a(BARE);
			r ::= ret.mut_ptr_ok();
			r->LocalPos := lhs->LocalPos;
			r->Op := op;
			r->Position := opPosition;
			r->Range := lhs->Range;
			r->Operands += &&lhs;
			= :<>(&&ret);
		}

		STATIC make_binary(
			op: rlc::Operator,
			opPosition: src::Position,
			lhs: [Stage]Expression - std::Val,
			rhs: [Stage]Expression - std::Val
		) [Stage]Expression - std::Val
		{
			ret: OperatorExpression-std::Val := :a(BARE);
			r ::= ret.mut_ptr_ok();
			r->LocalPos := lhs->LocalPos;
			r->Op := op;
			r->Position := opPosition;
			r->Range := lhs->Range.span(rhs->Range);
			r->Operands += &&lhs;
			r->Operands += &&rhs;
			= :<>(&&ret);
		}
	}

	/// `THIS` expression.
	[Stage: TYPE] ThisExpression -> [Stage]Expression
	{
		:transform{
			p: [Stage::Prev+]ThisExpression #&,
			ctx: Stage::Context+ #&
		} -> (:transform, p, ctx);
	}

	/// `NULL` expression.
	[Stage: TYPE] NullExpression -> [Stage]Expression
	{
		:transform{
			p: [Stage::Prev+]NullExpression #&,
			ctx: Stage::Context+ #&
		} -> (:transform, p, ctx);
	}

	/// `BARE` expression.
	[Stage: TYPE] BareExpression -> [Stage]Expression
	{
		:transform{
			p: [Stage::Prev+]BareExpression #&,
			ctx: Stage::Context+ #&
		} -> (:transform, p, ctx);
	}

	/// Static, dynamic, or factory cast expression.
	[Stage: TYPE] CastExpression -> [Stage]Expression
	{
		ENUM Kind { static, dynamic, mask }

		Method: Kind;
		Type: ast::[Stage]Type-std::Val;
		Values: [Stage]Expression - std::ValVec;

		:transform{
			p: [Stage::Prev+]CastExpression #&,
			ctx: Stage::Context+ #&
		} -> (:transform, p, ctx):
			Method := p.Method,
			Type := :make(p.Type!, ctx),
			Values := :reserve(##p.Values)
		{
			FOR(v ::= p.Values.start())
				Values += :make(v!, ctx);
		}
	}

	/// `SIZEOF` expression.
	[Stage: TYPE] SizeofExpression -> [Stage]Expression
	{
		Term: [Stage]TypeOrExpr - std::Val;
		Variadic: BOOL;

		:transform{
			p: [Stage::Prev+]SizeofExpression #&,
			ctx: Stage::Context+ #&
		} -> (:transform, p, ctx):
			Term := :make(p.Term!, ctx),
			Variadic := p.Variadic;
	}

	/// `TYPE`, `TYPE STATIC`, `TYPE TYPE` expressions.
	[Stage: TYPE] TypeofExpression -> [Stage]Expression
	{
		Term: [Stage]TypeOrExpr - std::Val;
		StaticExp: BOOL; // Only affects expressions.

		:transform{
			p: [Stage::Prev+]TypeofExpression #&,
			ctx: Stage::Context+ #&
		} -> (:transform, p, ctx):
			Term := :make(p.Term!, ctx),
			StaticExp := p.StaticExp;
	}

	/// `COPY_RTTI` expression.
	[Stage: TYPE] CopyRttiExpression -> [Stage]Expression
	{
		Source: [Stage]Expression - std::Val;
		Dest: [Stage]Expression - std::Val;

		:transform{
			p: [Stage::Prev+]CopyRttiExpression #&,
			ctx: Stage::Context+ #&
		} -> (:transform, p, ctx):
			Source := :make(p.Source!, ctx),
			Dest := :make(p.Dest!, ctx);
	}

	[Stage: TYPE] BaseExpression -> [Stage]Expression
	{
		Index: Stage::Number+ - std::Opt;
		Name: Stage::Symbol+ - std::Opt;

		:transform{
			p: [Stage::Prev+]BaseExpression #&,
			ctx: Stage::Context+ #&
		} -> (:transform, p, ctx)
		{
			IF(p.Index)
				Index := :a(ctx.transform_number(p.Index!));
			ELSE
				Name := :a(ctx.transform_symbol(p.Name!, 0));
		}
	}
}