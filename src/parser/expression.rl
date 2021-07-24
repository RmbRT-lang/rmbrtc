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
	count,
	baseAddr,

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
		null,
		cast,
		sizeof
	}

	Expression VIRTUAL
	{
		# ABSTRACT type() ExpressionType;

		Range: src::String;
		Position: src::Position;

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
						op := std::[OperatorExpression]new();
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
			|| [NullExpression]parse_impl(p, ret)
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
		PRIVATE STATIC parse_impl(p: Parser &, ret: Expression * &) BOOL
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

		parse(p: Parser &) BOOL
		{
			IF(!p.consume(:colon))
				RETURN FALSE;
			p.expect(:identifier, &Symbol, &THIS.Position);
			RETURN TRUE;
		}
	}

	NumberExpression -> Expression
	{
		# FINAL type() ExpressionType := :number;

		Number: src::String;

		parse(p: Parser &) BOOL := p.consume(:numberLiteral, &Number, &THIS.Position);
	}

	BoolExpression -> Expression
	{
		# FINAL type() ExpressionType := :bool;

		Value: BOOL;

		parse(p: Parser&) BOOL
		{
			IF(p.consume(:true, &THIS.Position))
			{
				Value := TRUE;
			} ELSE IF(p.consume(:false, &THIS.Position))
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

		parse(p: Parser &) BOOL := p.consume(:stringApostrophe, &Char, &THIS.Position);
	}

	StringExpression -> Expression
	{
		# FINAL type() ExpressionType := :string;

		String: src::String;

		parse(p: Parser &) BOOL := p.consume(:stringQuote, &String, &THIS.Position);
	}

	::detail
	{
		BinOpDesc
		{
			[N: NUMBER]
			{
				// (token, operator, UserOverloadable)
				table: {tok::Type, Operator, BOOL}#[N] &,
				leftAssoc: BOOL
			}:
				Table(table),
				Size(N),
				LeftAssoc(leftAssoc);

			Table: {tok::Type, Operator, BOOL}# \;
			Size: UM;
			LeftAssoc: BOOL;
		}

		k_bind: {tok::Type, Operator, BOOL}#[](
			// bind operators.
			(:dotAsterisk, :bindReference, FALSE),
			(:minusGreaterAsterisk, :bindPointer, FALSE));

		k_mul: {tok::Type, Operator, BOOL}#[](
			// multiplicative operators.
			(:percent, :mod, TRUE),
			(:forwardSlash, :div, TRUE),
			(:asterisk, :mul, TRUE));

		k_add: {tok::Type, Operator, BOOL}#[](
			// additive operators.
			(:minus, :sub, TRUE),
			(:plus, :add, TRUE));

		k_shift: {tok::Type, Operator, BOOL}#[](
			// bit shift operators.
			(:doubleLess, :shiftLeft, TRUE),
			(:doubleGreater, :shiftRight, TRUE),
			(:tripleLess, :rotateLeft, TRUE),
			(:tripleGreater, :rotateRight, TRUE));

		k_bit: {tok::Type, Operator, BOOL}#[](
			// bit arithmetic operators.
			(:and, :bitAnd, TRUE),
			(:circumflex, :bitXor, TRUE),
			(:pipe, :bitOr, TRUE));

		k_cmp: {tok::Type, Operator, BOOL}#[](
			// numeric comparisons.
			(:less, :less, TRUE),
			(:lessEqual, :lessEquals, TRUE),
			(:greater, :greater, TRUE),
			(:greaterEqual, :greaterEquals, TRUE),
			(:doubleEqual, :equals, TRUE),
			(:exclamationMarkEqual, :notEquals, TRUE));

		k_log_and: {tok::Type, Operator, BOOL}#[](
			// boolean arithmetic.
			(:doubleAnd, :logAnd, TRUE),
			(:doubleAnd, :logAnd, TRUE));

		k_log_or: {tok::Type, Operator, BOOL}#[](
			(:doublePipe, :logOr, TRUE),
			(:doublePipe, :logOr, TRUE));

		k_assign: {tok::Type, Operator, BOOL}#[](
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

		precedenceGroups: UM# := ##k_groups;

		// (tok, op, user-overloadable)
		k_prefix_ops: {tok::Type, Operator, BOOL}#[](
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
				(:lessMinus, :await, TRUE),
				(:doubleHash, :count, TRUE),
				(:tripleAnd, :baseAddr, FALSE));

		consume_overloadable_binary_operator(p: Parser &, op: Operator &) BOOL
		{
			FOR(i ::= 0; i < ##k_groups; i++)
				FOR(j ::= 0; j < k_groups[i].Size; j++)
					IF(k_groups[i].Table[j].(2))
						IF(p.consume(k_groups[i].Table[j].(0)))
						{
							op := k_groups[i].Table[j].(1);
							RETURN TRUE;
						}
			RETURN FALSE;
		}

		consume_overloadable_prefix_operator(p: Parser &, op: Operator &) BOOL
		{
			FOR(i ::= 0; i < ##k_prefix_ops; i++)
				IF(k_prefix_ops[i].(2))
					IF(p.consume(k_prefix_ops[i].(0)))
					{
						op := k_prefix_ops[i].(1);
						RETURN TRUE;
					}
			RETURN FALSE;
		}

		consume_overloadable_postfix_operator(p: Parser &, op: Operator &) BOOL
		{
			STATIC k_postfix_ops: {tok::Type, Operator}#[](
				(:doublePlus, :postIncrement),
				(:doubleMinus, :postDecrement));

			FOR(i ::= 0; i < ##k_postfix_ops; i++)
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

		Operands: Expression - std::DynVector;
		Op: Operator;

		STATIC parse(p: Parser&) INLINE Expression *
			:= parse_binary(p, detail::precedenceGroups);

		STATIC parse_binary_rhs(
			p: Parser&,
			lhs: Expression *,
			level: UINT) Expression *
		{
			IF(level == 0)
				RETURN lhs;

			group ::= &detail::k_groups[level-1];
			FOR(i ::= 0; i < group->Size; i++)
			{
				IF(p.consume(group->Table[i].(0)))
				{
					op ::= group->Table[i].(1);
					ret ::= std::[OperatorExpression]new();
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
			level: UINT) Expression *
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

				ret ::= std::[OperatorExpression]new();
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
			FOR(i ::= 0; i < ##detail::k_prefix_ops; i++)
				IF(p.consume(detail::k_prefix_ops[i].(0)))
				{
					xp ::= std::[OperatorExpression]new();
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
			ret ::= std::[OperatorExpression]new();
			ret->Op := op;
			ret->Operands += :gc(lhs);
			ret->Position := lhs->Position;
			RETURN ret;
		}

		PRIVATE STATIC make_binary(
			op: Operator,
			lhs: Expression *,
			rhs: Expression *) Expression *
		{
			ret ::= std::[OperatorExpression]new();
			ret->Op := op;
			ret->Operands += :gc(lhs);
			ret->Operands += :gc(rhs);
			ret->Position := lhs->Position;
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

			// (tok, op, opctor, opTuple, opDtor)
			STATIC memberAccess: {tok::Type, Operator, Operator, Operator, Operator}#[](
				(:dot, :memberReference, :constructor, :tupleMemberReference, :destructor),
				(:minusGreater, :memberPointer, :pointerConstructor, :tupleMemberPointer, :pointerDestructor));

			FOR["outer"](;;)
			{
				FOR(i ::= 0; i < ##postfix; i++)
				{
					IF(p.consume(postfix[i].(0)))
					{
						lhs := make_unary(postfix[i].(1), lhs);
						CONTINUE["outer"];
					}
				}

				IF(p.consume(:bracketOpen))
				{
					sub ::= std::[OperatorExpression]new();
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
					call ::= std::[OperatorExpression]new();
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

				FOR(i ::= 0; i < ##memberAccess; i++)
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
						} ELSE IF(p.consume(:tilde))
						{
							lhs := make_unary(memberAccess[i].(4), lhs);
						}
						ELSE
						{
							member: SymbolChildExpression;
							IF(!member.parse(p))
								p.fail("expected member name");

							lhs := make_binary(
								memberAccess[i].(1),
								lhs,
								std::[TYPE(member)]new(&&member));
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

		parse(p: Parser&) BOOL := p.consume(:this, &THIS.Position);
	}

	NullExpression -> Expression
	{
		# FINAL type() ExpressionType := :null;

		parse(p: Parser&) BOOL := p.consume(:null, &THIS.Position);
	}

	CastExpression -> Expression
	{
		# FINAL type() ExpressionType := :cast;

		ENUM Kind { static, dynamic, mask }
		Method: Kind;
		Type: std::[parser::Type]Dynamic;
		Values: Expression - std::DynVector;

		parse(p: Parser&) BOOL
		{
			// (method, open, close, allow multiple args, expect args)
			STATIC lookup: {Kind, tok::Type, tok::Type, BOOL, BOOL}#[](
				(:static, :less, :greater, TRUE, FALSE),
				(:dynamic, :doubleLess, :doubleGreater, FALSE, TRUE),
				(:mask, :tripleLess, :tripleGreater, TRUE, TRUE)
			);
			type: UM;
			FOR(type := 0; type < ##lookup; type++)
				IF(p.consume(lookup[type].(1), &THIS.Position))
					BREAK;
			IF(type == ##lookup)
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
		PRIVATE V: util::[Expression; Type]DynUnion;

		{};
		{:gc, v: Expression \}: V(:gc, v);
		{:gc, v: Type \}: V(:gc, v);
		{v: TypeOrExpr &&}: V(&&v.V);
		
		# is_type() INLINE BOOL := V.is_second();
		# type() Type \ := V.second();
		# is_expression() INLINE BOOL := V.is_first();
		# expression() INLINE Expression \ := V.first();

		# <BOOL> INLINE := V;
		# !THIS INLINE BOOL := !V;

		[T:TYPE] THIS:=(v: T! &&) TypeOrExpr &
			:= std::help::custom_assign(THIS, <T!&&>(v));
	}

	SizeofExpression -> Expression
	{
		# FINAL type() ExpressionType := :sizeof;

		Term: TypeOrExpr;

		# is_expression() INLINE BOOL := Term.is_expression();
		# is_type() INLINE BOOL := Term.is_type();

		parse(p: Parser&) BOOL
		{
			IF(!p.consume(:sizeof))
				RETURN FALSE;

			t: Trace(&p, "sizeof expression");

			p.expect(:parentheseOpen);
			IF(p.consume(:hash))
			{
				IF(exp ::= Expression::parse(p))
					Term := :gc(exp);
				ELSE
					p.fail("expected expression");
			} ELSE
			{
				IF(type ::= Type::parse(p))
					Term := :gc(type);
				ELSE
					p.fail("expected type");
			}

			p.expect(:parentheseClose);

			RETURN TRUE;
		}
	}
}