INCLUDE "symbol.rl"
INCLUDE "parser.rl"
INCLUDE "type.rl"

INCLUDE "../util/dynunion.rl"

INCLUDE 'std/vector'

::rlc ENUM Operator
{
	add, sub, mul, div, mod,
	equals, notEquals, less, lessEquals, greater, greaterEquals,
	bitAnd, bitOr, bitXor, bitNot,
	logAnd, logOr, logNot,
	shiftLeft, shiftRight, rotateLeft, rotateRight,
	neg, pos,
	subscript, call, conditional,
	memberReference, memberPointer,
	bindReference, bindPointer,
	dereference, address,
	preIncrement, preDecrement,
	postIncrement, postDecrement,

	async,
	fullAsync,
	expectDynamic,
	maybeDynamic,

	assign,
	addAssign, subAssign, mulAssign, divAssign, modAssign,
	bitAndAssign, bitOrAssign, bitXorAssign, bitNotAssign,
	logAndAssign, logOrAssign, logNotAssign,
	shiftLeftAssign, shiftRightAssign, rotateLeftAssign, rotateRightAssign,
	negAssign,

	tuple
}

::rlc::parser
{
	ENUM ExpressionType
	{
		symbol,
		symbolChild,
		symbolConstant,
		number,
		bool,
		char,
		string,
		operator,
		this,
		cast,
		sizeof
	}

	Expression VIRTUAL
	{
		# ABSTRACT type() ExpressionType;

		Range: src::String;

		STATIC parse_atom(
			p: Parser &) Expression *
		{
			IF(p.consume(:parentheseOpen))
			{
				exp ::= Expression::parse(p);
				IF(!exp)
					p.fail("expected expression");

				op: OperatorExpression * := NULL;
				WHILE(p.consume(:comma))
				{
					IF(!op)
					{
						op := ::[OperatorExpression]new();
						op->Op := :tuple;
						op->Operands += :gc(exp);
					}

					IF(!(exp := Expression::parse(p)))
						p.fail("expected expression");
					op->Operands += :gc(exp);
				}
				p.expect(:parentheseClose);

				RETURN op ? op : exp;
			}

			ret: Expression *;
			IF([SymbolExpression]parse_impl(p, ret)
			|| [SymbolChildExpression]parse_impl(p, ret)
			|| [SymbolConstantExpression]parse_impl(p, ret)
			|| [NumberExpression]parse_impl(p, ret)
			|| [BoolExpression]parse_impl(p, ret)
			|| [CharExpression]parse_impl(p, ret)
			|| [StringExpression]parse_impl(p, ret)
			|| [ThisExpression]parse_impl(p, ret)
			|| [CastExpression]parse_impl(p, ret)
			|| [SizeofExpression]parse_impl(p, ret))
			{
				RETURN ret;
			}

			RETURN NULL;
		}

		STATIC parse(p: Parser &) INLINE Expression *
			:= OperatorExpression::parse(p);

		[T:TYPE]
		PRIVATE STATIC parse_impl(p: Parser &, ret: Expression * &) bool
		{
			v: T;
			IF(v.parse(p))
			{
				ret := std::dup(&&v);
				RETURN TRUE;
			}
			RETURN FALSE;
		}
	}

	SymbolConstantExpression -> Expression
	{
		# FINAL type() ExpressionType := :symbolConstant;

		Symbol: src::String;

		parse(p: Parser &) bool
		{
			IF(!p.consume(:colon))
				RETURN FALSE;
			p.expect(:identifier, &Symbol);
			RETURN TRUE;
		}
	}

	NumberExpression -> Expression
	{
		# FINAL type() ExpressionType := :number;

		Number: src::String;

		parse(p: Parser &) bool := p.consume(:numberLiteral, &Number);
	}

	BoolExpression -> Expression
	{
		# FINAL type() ExpressionType := :bool;

		Value: bool;

		parse(p: Parser&) bool
		{
			IF(p.consume(:true))
			{
				Value := TRUE;
			} ELSE IF(p.consume(:false))
			{
				Value := FALSE;
			} ELSE
				RETURN FALSE;
			RETURN TRUE;
		}
	}

	CharExpression -> Expression
	{
		# FINAL type() ExpressionType := :char;

		Char: src::String;

		parse(p: Parser &) bool := p.consume(:stringApostrophe, &Char);
	}

	StringExpression -> Expression
	{
		# FINAL type() ExpressionType := :string;

		String: src::String;

		parse(p: Parser &) bool := p.consume(:stringQuote, &String);
	}

	::detail
	{
		BinOpDesc
		{
			[N: NUMBER]
			{
				table: {tok::Type, Operator}#[N] &,
				leftAssoc: bool
			}:
				Table(table),
				Size(N),
				LeftAssoc(leftAssoc);

			Table: {tok::Type, Operator}# \;
			Size: UM;
			LeftAssoc: bool;
		}

		k_bind: {tok::Type, Operator}#[](
			// bind operators.
			(:dotAsterisk, :bindReference),
			(:minusGreaterAsterisk, :bindPointer));

		k_mul: {tok::Type, Operator}#[](
			// multiplicative operators.
			(:percent, :mod),
			(:forwardSlash, :div),
			(:asterisk, :mul));

		k_add: {tok::Type, Operator}#[](
			// additive operators.
			(:minus, :sub),
			(:plus, :add));

		k_shift: {tok::Type, Operator}#[](
			// bit shift operators.
			(:doubleLess, :shiftLeft),
			(:doubleGreater, :shiftRight),
			(:tripleLess, :rotateLeft),
			(:tripleGreater, :rotateRight));

		k_bit: {tok::Type, Operator}#[](
			// bit arithmetic operators.
			(:and, :bitAnd),
			(:circumflex, :bitXor),
			(:pipe, :bitOr));

		k_cmp: {tok::Type, Operator}#[](
			// numeric comparisons.
			(:less, :less),
			(:lessEqual, :lessEquals),
			(:greater, :greater),
			(:greaterEqual, :greaterEquals),
			(:doubleEqual, :equals),
			(:exclamationMarkEqual, :notEquals));

		k_log_and: {tok::Type, Operator}#[](
			// boolean arithmetic.
			(:doubleAnd, :logAnd),
			(:doubleAnd, :logAnd));

		k_log_or: {tok::Type, Operator}#[](
			(:doublePipe, :logOr),
			(:doublePipe, :logOr));

		k_assign: {tok::Type, Operator}#[](
			// assignments.
			(:colonEqual, :assign),
			(:plusEqual, :addAssign),
			(:minusEqual, :subAssign),
			(:asteriskEqual, :mulAssign),
			(:forwardSlashEqual, :divAssign),
			(:percentEqual, :modAssign),
			(:andEqual, :bitAndAssign),
			(:pipeEqual, :bitOrAssign),
			(:circumflexEqual, :bitXorAssign),
			(:doubleAndEqual, :logAndAssign),
			(:doublePipeEqual, :logOrAssign),
			(:doubleLessEqual, :shiftLeftAssign),
			(:doubleGreaterEqual, :shiftRightAssign),
			(:tripleLessEqual, :rotateLeftAssign),
			(:tripleGreaterEqual, :rotateRightAssign));

		k_groups: BinOpDesc#[](
			(k_bind, TRUE),
			(k_mul, TRUE),
			(k_add, TRUE),
			(k_shift, TRUE),
			(k_bit, TRUE),
			(k_cmp, TRUE),
			(k_log_and, TRUE),
			(k_log_or, TRUE),
			(k_assign, FALSE));

		precedenceGroups: UM# := ::size(k_groups);
	}

	OperatorExpression -> Expression
	{
		# FINAL type() ExpressionType := :operator;

		Operands: std::[std::[Expression]Dynamic]Vector;
		Op: Operator;

		STATIC parse(p: Parser&) INLINE Expression *
			:= parse_binary(p, detail::precedenceGroups);

		STATIC parse_binary_rhs(
			p: Parser&,
			lhs: Expression *,
			level: uint) Expression *
		{
			IF(level == 0)
				RETURN lhs;

			group ::= &detail::k_groups[level-1];
			FOR(i ::= 0; i < group->Size; i++)
			{
				IF(p.consume(group->Table[i].(0)))
				{
					op ::= group->Table[i].(1);
					ret ::= ::[OperatorExpression]new();
					ret->Op := op;
					ret->Operands += :gc(lhs);

					IF(group->LeftAssoc)
					{
						// a + b + c
						// (a + b) + c
						rhs ::= parse_binary(p, level-1);
						IF(!rhs)
							p.fail("expected expression");
						ret->Operands += :gc(rhs);
						RETURN parse_binary_rhs(p, ret, level);
					} ELSE
					{
						// a := b := c
						// a := (b := c)
						rhs ::= parse_binary(p, level);
						IF(!rhs)
							p.fail("expected expression");

						ret->Operands += :gc(rhs);
						RETURN ret;
					}
				}
			}

			RETURN lhs;
		}

		STATIC parse_binary(
			p: Parser&,
			level: uint) Expression *
		{
			lhs ::= level
				? parse_binary(p, level-1)
				: parse_prefix(p);
			IF(!lhs)
				RETURN NULL;

			IF(level == detail::precedenceGroups
			&& p.consume(:questionMark))
			{
				then ::= Expression::parse(p);
				p.expect(:colon);
				else ::= Expression::parse(p);

				ret ::= [OperatorExpression]new();
				ret->Op := :conditional;
				ret->Operands += :gc(lhs);
				ret->Operands += :gc(then);
				ret->Operands += :gc(else);
				RETURN ret;
			} ELSE
				RETURN parse_binary_rhs(p, lhs, level);
		}

		STATIC parse_prefix(p: Parser&) Expression *
		{
			STATIC prefix: {tok::Type, Operator}#[](
				(:minus, :neg),
				(:plus, :pos),
				(:doublePlus, :preIncrement),
				(:doubleMinus, :preDecrement),
				(:tilde, :bitNot),
				(:tildeColon, :bitNotAssign),
				(:exclamationMark, :logNot),
				(:exclamationMarkColon, :logNotAssign),
				(:and, :address),
				(:asterisk, :dereference));

			FOR(i ::= 0; i < ::size(prefix); i++)
				IF(p.consume(prefix[i].(0)))
				{
					xp ::= [OperatorExpression]new();
					xp->Op := prefix[i].(1);
					xp->Operands += :gc(parse_prefix(p));
					RETURN xp;
				}

			RETURN parse_postfix(p);
		}

		PRIVATE STATIC make_unary(
			op: Operator,
			lhs: Expression *) Expression *
		{
			ret ::= ::[OperatorExpression]new();
			ret->Op := op;
			ret->Operands += :gc(lhs);
			RETURN ret;
		}

		PRIVATE STATIC make_binary(
			op: Operator,
			lhs: Expression *,
			rhs: Expression *) Expression *
		{
			ret ::= ::[OperatorExpression]new();
			ret->Op := op;
			ret->Operands += :gc(lhs);
			ret->Operands += :gc(rhs);
			RETURN ret;
		}

		STATIC parse_postfix(
			p: Parser&) Expression *
		{
			lhs ::= Expression::parse_atom(p);
			IF(!lhs)
				RETURN NULL;

			STATIC postfix: {tok::Type, Operator}#[](
				(:doublePlus, :postIncrement),
				(:doubleMinus, :postDecrement));

			STATIC memberAccess: {tok::Type, Operator}#[](
				(:dot, :memberReference),
				(:minusGreater, :memberPointer));

			FOR["outer"](;;)
			{
				FOR(i ::= 0; i < ::size(postfix); i++)
				{
					IF(p.consume(postfix[i].(0)))
					{
						lhs := make_unary(postfix[i].(1), lhs);
						CONTINUE["outer"];
					}
				}

				IF(p.consume(:bracketOpen))
				{
					sub ::= ::[OperatorExpression]new();
					sub->Op := :subscript;
					sub->Operands += :gc(lhs);

					DO()
					{
						rhs ::= Expression::parse(p);
						IF(!rhs)
							p.fail("expected expression");
						sub->Operands += :gc(rhs);
					} WHILE(p.consume(:comma))
					p.expect(:bracketClose);

					lhs := sub;
					CONTINUE["outer"];
				}

				IF(p.consume(:parentheseOpen))
				{
					call ::= ::[OperatorExpression]new();
					call->Op := :call;
					call->Operands += :gc(lhs);

					FOR(comma ::= FALSE;
						!p.consume(:parentheseClose);
						comma := TRUE)
					{
						IF(comma)
							p.expect(:comma);
						IF(rhs ::= Expression::parse(p))
							call->Operands += :gc(rhs);
						ELSE
							p.fail("expected expression");
					}

					lhs := call;
					CONTINUE["outer"];
				}

				FOR(i ::= 0; i < ::size(memberAccess); i++)
				{
					IF(p.consume(memberAccess[i].(0)))
					{
						member: SymbolChildExpression;
						IF(!member.parse(p))
							p.fail("expected member name");

						lhs := make_binary(
							memberAccess[i].(1),
							lhs,
							::[TYPE(member)]new(&&member));
						CONTINUE["outer"];
					}
				}

				BREAK;
			}

			RETURN lhs;
		}
	}


	ThisExpression -> Expression
	{
		# FINAL type() ExpressionType := :this;

		parse(p: Parser&) bool := p.consume(:this);
	}

	CastExpression -> Expression
	{
		# FINAL type() ExpressionType := :cast;

		Type: std::[parser::Type]Dynamic;
		Value: std::[Expression]Dynamic;

		parse(p: Parser&) bool
		{
			IF(!p.consume(:less))
				RETURN FALSE;

			t: Trace(&p, "cast expression");

			IF(!(Type := :gc(parser::Type::parse(p))))
				p.fail("expected type");

			p.expect(:greater);
			p.expect(:parentheseOpen);

			value ::= Expression::parse(p);
			IF(!value)
				p.fail("expected expression");
			Value := :gc(value);

			p.expect(:parentheseClose);

			RETURN TRUE;
		}
	}

	TypeOrExpr
	{
		PRIVATE V: util::[Expression, Type]DynUnion;

		{};
		{v: Expression \}: V(v);
		{v: Type \}: V(v);
		{v: TypeOrExpr &&}: V(&&v.V);
		
		# is_type() INLINE bool := V.is_second();
		# type() Type \ := V.second();
		# is_expression() INLINE bool := V.is_first();
		# expression() INLINE Expression \ := V.first();

		# <bool> INLINE := V;
		# !THIS INLINE bool := !V;

		[T:TYPE] THIS:=(v: T! &&) TypeOrExpr &
			:= std::help::custom_assign(THIS, <T!&&>(v));
	}

	SizeofExpression -> Expression
	{
		# FINAL type() ExpressionType := :sizeof;

		Term: TypeOrExpr;

		# is_expression() INLINE bool := Term.is_expression();
		# is_type() INLINE bool := Term.is_type();

		parse(p: Parser&) bool
		{
			IF(!p.consume(:sizeof))
				RETURN FALSE;

			t: Trace(&p, "sizeof expression");

			p.expect(:parentheseOpen);
			IF(p.consume(:hash))
			{
				IF(!(Term := Expression::parse(p)))
					p.fail("expected expression");
			} ELSE
			{
				IF(!(Term := Type::parse(p)))
					p.fail("expected type");
			}

			p.expect(:parentheseClose);

			RETURN TRUE;
		}
	}
}