INCLUDE "symbol.rl"
INCLUDE "parser.rl"
INCLUDE "type.rl"

INCLUDE "../util/dynunion.rl"

INCLUDE 'std/vector'

::rlc ENUM Operator
{
	add, sub, mul, div, mod,
	equals, notEquals, less, lessEquals, greater, greaterEquals, cmp,
	bitAnd, bitOr, bitXor, bitNot,
	logAnd, logOr, logNot,
	shiftLeft, shiftRight, rotateLeft, rotateRight,
	neg, pos,
	subscript, call, conditional,
	memberReference, memberPointer, tupleMemberReference, tupleMemberPointer,
	bindReference, bindPointer,
	dereference, address, move,
	preIncrement, preDecrement,
	postIncrement, postDecrement,

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
	pointerConstructor
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
				table: {tok::Type, Operator, bool}#[N] &,
				leftAssoc: bool
			}:
				Table(table),
				Size(N),
				LeftAssoc(leftAssoc);

			Table: {tok::Type, Operator, bool}# \;
			Size: UM;
			LeftAssoc: bool;
		}

		k_bind: {tok::Type, Operator, bool}#[](
			// bind operators.
			(:dotAsterisk, :bindReference, FALSE),
			(:minusGreaterAsterisk, :bindPointer, FALSE));

		k_mul: {tok::Type, Operator, bool}#[](
			// multiplicative operators.
			(:percent, :mod, TRUE),
			(:forwardSlash, :div, TRUE),
			(:asterisk, :mul, TRUE));

		k_add: {tok::Type, Operator, bool}#[](
			// additive operators.
			(:minus, :sub, TRUE),
			(:plus, :add, TRUE));

		k_shift: {tok::Type, Operator, bool}#[](
			// bit shift operators.
			(:doubleLess, :shiftLeft, TRUE),
			(:doubleGreater, :shiftRight, TRUE),
			(:tripleLess, :rotateLeft, TRUE),
			(:tripleGreater, :rotateRight, TRUE));

		k_bit: {tok::Type, Operator, bool}#[](
			// bit arithmetic operators.
			(:and, :bitAnd, TRUE),
			(:circumflex, :bitXor, TRUE),
			(:pipe, :bitOr, TRUE));

		k_cmp: {tok::Type, Operator, bool}#[](
			// numeric comparisons.
			(:less, :less, FALSE),
			(:lessEqual, :lessEquals, FALSE),
			(:greater, :greater, FALSE),
			(:greaterEqual, :greaterEquals, FALSE),
			(:doubleEqual, :equals, FALSE),
			(:exclamationMarkEqual, :notEquals, FALSE),
			(:lessGreater, :cmp, TRUE));

		k_log_and: {tok::Type, Operator, bool}#[](
			// boolean arithmetic.
			(:doubleAnd, :logAnd, TRUE),
			(:doubleAnd, :logAnd, TRUE));

		k_log_or: {tok::Type, Operator, bool}#[](
			(:doublePipe, :logOr, TRUE),
			(:doublePipe, :logOr, TRUE));

		k_assign: {tok::Type, Operator, bool}#[](
			// assignments.
			(:colonEqual, :assign, TRUE),
			(:plusEqual, :addAssign, TRUE),
			(:minusEqual, :subAssign, TRUE),
			(:asteriskEqual, :mulAssign, TRUE),
			(:forwardSlashEqual, :divAssign, TRUE),
			(:percentEqual, :modAssign, TRUE),
			(:andEqual, :bitAndAssign, TRUE),
			(:pipeEqual, :bitOrAssign, TRUE),
			(:circumflexEqual, :bitXorAssign, TRUE),
			(:doubleAndEqual, :logAndAssign, TRUE),
			(:doublePipeEqual, :logOrAssign, TRUE),
			(:doubleLessEqual, :shiftLeftAssign, TRUE),
			(:doubleGreaterEqual, :shiftRightAssign, TRUE),
			(:tripleLessEqual, :rotateLeftAssign, TRUE),
			(:tripleGreaterEqual, :rotateRightAssign, TRUE));

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

		k_prefix_ops: {tok::Type, Operator, bool}#[](
				(:minus, :neg, TRUE),
				(:plus, :pos, TRUE),
				(:doublePlus, :preIncrement, TRUE),
				(:doubleMinus, :preDecrement, TRUE),
				(:tilde, :bitNot, TRUE),
				(:tildeColon, :bitNotAssign, TRUE),
				(:exclamationMark, :logNot, TRUE),
				(:exclamationMarkColon, :logNotAssign, TRUE),
				(:and, :address, FALSE),
				(:doubleAnd, :move, FALSE),
				(:asterisk, :dereference, TRUE),
				(:lessMinus, :await, TRUE));

		consume_overloadable_binary_operator(p: Parser &, op: Operator &) bool
		{
			FOR(i ::= 0; i < ::size(k_groups); i++)
				FOR(j ::= 0; j < k_groups[i].Size; j++)
					IF(k_groups[i].Table[j].(2))
						IF(p.consume(k_groups[i].Table[j].(0)))
						{
							op := k_groups[i].Table[j].(1);
							RETURN TRUE;
						}
			RETURN FALSE;
		}

		consume_overloadable_prefix_operator(p: Parser &, op: Operator &) bool
		{
			FOR(i ::= 0; i < ::size(k_prefix_ops); i++)
				IF(k_prefix_ops[i].(2))
					IF(p.consume(k_prefix_ops[i].(0)))
					{
						op := k_prefix_ops[i].(1);
						RETURN TRUE;
					}
			RETURN FALSE;
		}

		consume_overloadable_postfix_operator(p: Parser &, op: Operator &) bool
		{
			STATIC k_postfix_ops: {tok::Type, Operator}#[](
				(:doublePlus, :postIncrement),
				(:doubleMinus, :postDecrement));

			FOR(i ::= 0; i < ::size(k_postfix_ops); i++)
				IF(p.consume(k_postfix_ops[i].(0)))
				{
					op := k_postfix_ops[i].(1);
					RETURN TRUE;
				}
			RETURN FALSE;
		}
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
			FOR(i ::= 0; i < ::size(detail::k_prefix_ops); i++)
				IF(p.consume(detail::k_prefix_ops[i].(0)))
				{
					xp ::= [OperatorExpression]new();
					xp->Op := detail::k_prefix_ops[i].(1);
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
				(:doubleMinus, :postDecrement),
				(:tripleDot, :variadicExpand));

			STATIC memberAccess: {tok::Type, Operator, Operator, Operator}#[](
				(:dot, :memberReference, :constructor, :tupleMemberReference),
				(:minusGreater, :memberPointer, :pointerConstructor, :tupleMemberPointer));

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
						IF(p.consume(:braceOpen))
						{
							lhs := make_unary(memberAccess[i].(2), lhs);
							IF(!p.consume(:braceClose))
							{
								DO()
								{
									IF(arg ::= Expression::parse(p))
										<OperatorExpression \>(lhs)->Operands += :gc(arg);
									ELSE
										p.fail("expected expression");
								} WHILE(p.consume(:comma))
								p.expect(:braceClose);
							}
						}
						ELSE IF(p.consume(:parentheseOpen))
						{
							IF(index ::= Expression::parse(p))
								lhs := make_binary(memberAccess[i].(3), lhs, index);
							ELSE p.fail("expected expression");
							p.expect(:parentheseClose);
						}
						ELSE
						{
							member: SymbolChildExpression;
							IF(!member.parse(p))
								p.fail("expected member name");

							lhs := make_binary(
								memberAccess[i].(1),
								lhs,
								::[TYPE(member)]new(&&member));
						}
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

		ENUM Kind { static, dynamic }
		Method: Kind;
		Type: std::[parser::Type]Dynamic;
		Values: Expression - std::Dynamic - std::Vector;

		parse(p: Parser&) bool
		{
			// (method, open, close, allow multiple args, expect args)
			STATIC lookup: {Kind, tok::Type, tok::Type, bool, bool}#[](
				(:static, :less, :greater, TRUE, FALSE),
				(:dynamic, :doubleLess, :doubleGreater, FALSE, TRUE)
			);
			type: UM;
			FOR(type := 0; type < ::size(lookup); type++)
				IF(p.consume(lookup[type].(1)))
					BREAK;
			IF(type == ::size(lookup))
				RETURN FALSE;

			t: Trace(&p, "cast expression");

			IF(!(Type := :gc(parser::Type::parse(p))))
				p.fail("expected type");

			p.expect(lookup[type].(2));
			p.expect(:parentheseOpen);
			IF(lookup[type].(4) || !p.consume(:parentheseClose))
			{
				DO()
					IF(value ::= Expression::parse(p))
						Values += :gc(value);
					ELSE
						p.fail("expected expression");
					WHILE(lookup[type].(3) && p.consume(:comma))

				p.expect(:parentheseClose);
			}

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