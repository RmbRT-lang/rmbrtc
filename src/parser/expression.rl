INCLUDE "symbol.rl"
INCLUDE "parser.rl"
INCLUDE "type.rl"

INCLUDE "../util/dynunion.rl"

INCLUDE 'std/vector'

::rlc::parser
{
	ENUM ExpressionType
	{
		symbol,
		symbolChild,
		number,
		bool,
		char,
		string,
		operator,
		this,
		cast,
		sizeof
	}

	Expression
	{
		# ABSTRACT type() ExpressionType;

		Range: src::String;

		STATIC parse_atom(
			p: Parser &) Expression *
		{
			IF(p.consume(tok::Type::parentheseOpen))
			{
				exp ::= Expression::parse(p);
				p.expect(tok::Type::parentheseClose);
			}

			ret: Expression *;
			IF([SymbolExpression]parse_impl(p, ret)
			|| [SymbolChildExpression]parse_impl(p, ret)
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
				ret := std::dup(__cpp_std::move(v));
				RETURN TRUE;
			}
			RETURN FALSE;
		}
	}

	NumberExpression -> Expression
	{
		# FINAL type() ExpressionType := ExpressionType::number;

		Number: src::String;

		parse(p: Parser &) bool := p.consume(tok::Type::numberLiteral, &Number);
	}

	BoolExpression -> Expression
	{
		# FINAL type() ExpressionType := ExpressionType::bool;

		Value: bool;

		parse(p: Parser&) bool
		{
			IF(p.consume(tok::Type::true))
			{
				Value := TRUE;
			} ELSE IF(p.consume(tok::Type::false))
			{
				Value := FALSE;
			} ELSE
				RETURN FALSE;
			RETURN TRUE;
		}
	}

	CharExpression -> Expression
	{
		# FINAL type() ExpressionType := ExpressionType::char;

		Char: src::String;

		parse(p: Parser &) bool := p.consume(tok::Type::stringApostrophe, &Char);
	}

	StringExpression -> Expression
	{
		# FINAL type() ExpressionType := ExpressionType::char;

		String: src::String;

		parse(p: Parser &) bool := p.consume(tok::Type::stringQuote, &String);
	}

	ENUM Operator
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
		negAssign
	}

	::detail
	{
		BinOpDesc
		{
			[N: NUMBER]
			CONSTRUCTOR(
				table: std::[tok::Type, Operator]Pair#[N] &,
				leftAssoc: bool):
				Table(table),
				Size(N),
				LeftAssoc(leftAssoc);

			Table: std::[tok::Type, Operator]Pair# \;
			Size: UM;
			LeftAssoc: bool;
		}

		k_bind: std::[tok::Type, Operator]Pair#[](
			// bind operators.
			std::pair(tok::Type::dotAsterisk, Operator::bindReference),
			std::pair(tok::Type::minusGreaterAsterisk, Operator::bindPointer));

		k_mul: std::[tok::Type, Operator]Pair#[](
			// multiplicative operators.
			std::pair(tok::Type::percent, Operator::mod),
			std::pair(tok::Type::forwardSlash, Operator::div),
			std::pair(tok::Type::asterisk, Operator::mul));

		k_add: std::[tok::Type, Operator]Pair#[](
			// additive operators.
			std::pair(tok::Type::minus, Operator::sub),
			std::pair(tok::Type::plus, Operator::add));

		k_shift: std::[tok::Type, Operator]Pair#[](
			// bit shift operators.
			std::pair(tok::Type::doubleLess, Operator::shiftLeft),
			std::pair(tok::Type::doubleGreater, Operator::shiftRight),
			std::pair(tok::Type::tripleLess, Operator::rotateLeft),
			std::pair(tok::Type::tripleGreater, Operator::rotateRight));

		k_bit: std::[tok::Type, Operator]Pair#[](
			// bit arithmetic operators.
			std::pair(tok::Type::and, Operator::bitAnd),
			std::pair(tok::Type::circumflex, Operator::bitXor),
			std::pair(tok::Type::pipe, Operator::bitOr));

		k_cmp: std::[tok::Type, Operator]Pair#[](
			// numeric comparisons.
			std::pair(tok::Type::less, Operator::less),
			std::pair(tok::Type::lessEqual, Operator::lessEquals),
			std::pair(tok::Type::greater, Operator::greater),
			std::pair(tok::Type::greaterEqual, Operator::greaterEquals),
			std::pair(tok::Type::doubleEqual, Operator::equals),
			std::pair(tok::Type::exclamationMarkEqual, Operator::notEquals));

		k_log_and: std::[tok::Type, Operator]Pair#[](
			// boolean arithmetic.
			std::pair(tok::Type::doubleAnd, Operator::logAnd),
			std::pair(tok::Type::doubleAnd, Operator::logAnd));

		k_log_or: std::[tok::Type, Operator]Pair#[](
			std::pair(tok::Type::doublePipe, Operator::logOr),
			std::pair(tok::Type::doublePipe, Operator::logOr));

		k_assign: std::[tok::Type, Operator]Pair#[](
			// assignments.
			std::pair(tok::Type::colonEqual, Operator::assign),
			std::pair(tok::Type::plusEqual, Operator::addAssign),
			std::pair(tok::Type::minusEqual, Operator::subAssign),
			std::pair(tok::Type::asteriskEqual, Operator::mulAssign),
			std::pair(tok::Type::forwardSlashEqual, Operator::divAssign),
			std::pair(tok::Type::percentEqual, Operator::modAssign),
			std::pair(tok::Type::andEqual, Operator::bitAndAssign),
			std::pair(tok::Type::pipeEqual, Operator::bitOrAssign),
			std::pair(tok::Type::circumflexEqual, Operator::bitXorAssign),
			std::pair(tok::Type::doubleAndEqual, Operator::logAndAssign),
			std::pair(tok::Type::doublePipeEqual, Operator::logOrAssign),
			std::pair(tok::Type::doubleLessEqual, Operator::shiftLeftAssign),
			std::pair(tok::Type::doubleGreaterEqual, Operator::shiftRightAssign),
			std::pair(tok::Type::tripleLessEqual, Operator::rotateLeftAssign),
			std::pair(tok::Type::tripleGreaterEqual, Operator::rotateRightAssign));

		k_groups: BinOpDesc#[](
			BinOpDesc(k_bind, TRUE),
			BinOpDesc(k_mul, TRUE),
			BinOpDesc(k_add, TRUE),
			BinOpDesc(k_shift, TRUE),
			BinOpDesc(k_bit, TRUE),
			BinOpDesc(k_cmp, TRUE),
			BinOpDesc(k_log_and, TRUE),
			BinOpDesc(k_log_or, TRUE),
			BinOpDesc(k_assign, FALSE));

		precedenceGroups: UM# := ::size(k_groups);
	}

	OperatorExpression -> Expression
	{
		# FINAL type() ExpressionType := ExpressionType::operator;

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
				IF(p.consume(group->Table[i].First))
				{
					op ::= group->Table[i].Second;
					ret ::= ::[OperatorExpression]new();
					ret->Op := op;
					ret->Operands.push_back(lhs);

					IF(group->LeftAssoc)
					{
						// a + b + c
						// (a + b) + c
						rhs ::= parse_binary(p, level-1);
						IF(!rhs)
							p.fail("expected expression");
						ret->Operands.push_back(rhs);
						RETURN parse_binary_rhs(p, ret, level);
					} ELSE
					{
						// a := b := c
						// a := (b := c)
						rhs ::= parse_binary(p, level);
						IF(!rhs)
							p.fail("expected expression");

						ret->Operands.push_back(rhs);
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
			&& p.consume(tok::Type::questionMark))
			{
				then ::= Expression::parse(p);
				p.expect(tok::Type::colon);
				else ::= Expression::parse(p);

				ret ::= [OperatorExpression]new();
				ret->Op := Operator::conditional;
				ret->Operands.push_back(lhs);
				ret->Operands.push_back(then);
				ret->Operands.push_back(else);
				RETURN ret;
			} ELSE
				RETURN parse_binary_rhs(p, lhs, level);
		}

		STATIC parse_prefix(p: Parser&) Expression *
		{
			STATIC prefix: std::[tok::Type, Operator]Pair#[](
				std::pair(tok::Type::minus, Operator::neg),
				std::pair(tok::Type::plus, Operator::pos),
				std::pair(tok::Type::doublePlus, Operator::preIncrement),
				std::pair(tok::Type::doubleMinus, Operator::preDecrement),
				std::pair(tok::Type::tildeColon, Operator::bitNotAssign),
				std::pair(tok::Type::exclamationMark, Operator::logNot),
				std::pair(tok::Type::exclamationMarkColon, Operator::logNotAssign),
				std::pair(tok::Type::and, Operator::address),
				std::pair(tok::Type::asterisk, Operator::dereference));

			FOR(i ::= 0; i < ::size(prefix); i++)
				IF(p.consume(prefix[i].First))
				{
					xp: OperatorExpression;
					xp.Operands.push_back(parse_prefix(p));
					RETURN [TYPE(xp)]new(__cpp_std::move(xp));
				}


			IF(p.consume(tok::Type::parentheseOpen))
			{
				xp ::= Expression::parse(p);
				p.expect(tok::Type::parentheseClose);
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
			ret->Operands.push_back(lhs);
			RETURN ret;
		}

		PRIVATE STATIC make_binary(
			op: Operator,
			lhs: Expression *,
			rhs: Expression *) Expression *
		{
			ret ::= ::[OperatorExpression]new();
			ret->Op := op;
			ret->Operands.push_back(lhs);
			ret->Operands.push_back(rhs);
			RETURN ret;
		}

		STATIC parse_postfix(
			p: Parser&) Expression *
		{
			lhs ::= Expression::parse_atom(p);
			IF(!lhs)
				RETURN NULL;

			STATIC postfix: std::[tok::Type, Operator]Pair#[](
				std::pair(tok::Type::doublePlus, Operator::postIncrement),
				std::pair(tok::Type::doubleMinus, Operator::postDecrement));

			STATIC memberAccess: std::[tok::Type, Operator]Pair#[](
				std::pair(tok::Type::dot, Operator::memberReference),
				std::pair(tok::Type::minusGreater, Operator::memberPointer));

			FOR["outer"](;;)
			{
				FOR(i ::= 0; i < ::size(postfix); i++)
				{
					IF(p.consume(postfix[i].First))
					{
						lhs := make_unary(postfix[i].Second, lhs);
						CONTINUE["outer"];
					}
				}

				IF(p.consume(tok::Type::bracketOpen))
				{
					sub ::= ::[OperatorExpression]new();
					sub->Op := Operator::subscript;
					sub->Operands.push_back(lhs);

					DO()
					{
						rhs ::= Expression::parse(p);
						IF(!rhs)
							p.fail("expected expression");
						sub->Operands.push_back(rhs);
					} WHILE(p.consume(tok::Type::comma))
					p.expect(tok::Type::bracketClose);

					lhs := sub;
					CONTINUE["outer"];
				}

				IF(p.consume(tok::Type::parentheseOpen))
				{
					call ::= ::[OperatorExpression]new();
					call->Op := Operator::call;
					call->Operands.push_back(lhs);

					DO()
					{
						rhs ::= Expression::parse(p);
						IF(!rhs)
							p.fail("expected expression");
						call->Operands.push_back(rhs);
					} WHILE(p.consume(tok::Type::comma))
					p.expect(tok::Type::parentheseClose);

					lhs := call;
					CONTINUE["outer"];
				}

				FOR(i ::= 0; i < ::size(memberAccess); i++)
				{
					IF(p.consume(memberAccess[i].First))
					{
						member: SymbolChildExpression;
						IF(!member.parse(p))
							p.fail("expected member name");

						lhs := make_binary(
							memberAccess[i].Second,
							lhs,
							::[TYPE(member)]new(__cpp_std::move(member)));
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
		# FINAL type() ExpressionType := ExpressionType::this;

		parse(p: Parser&) bool := p.consume(tok::Type::this);
	}

	CastExpression -> Expression
	{
		# FINAL type() ExpressionType := ExpressionType::cast;

		Type: std::[parser::Type]Dynamic;
		Value: std::[Expression]Dynamic;

		parse(p: Parser&) bool
		{
			IF(!p.consume(tok::Type::less))
				RETURN FALSE;

			t: Trace(&p, "cast expression");

			type ::= Type::parse(p);
			IF(!type)
				p.fail("expected type");
			Type := type;

			p.expect(tok::Type::greater);
			p.expect(tok::Type::parentheseOpen);

			value ::= Expression::parse(p);
			IF(!value)
				p.fail("expected expression");
			Value := value;

			p.expect(tok::Type::parentheseClose);

			RETURN TRUE;
		}
	}

	TypeOrExpr
	{
		PRIVATE V: util::[Expression, Type]DynUnion;

		CONSTRUCTOR();
		CONSTRUCTOR(v: Expression \): V(v);
		CONSTRUCTOR(v: Type \): V(v);
		
		# is_type() INLINE bool := V.is_second();
		# type() Type \ := V.second();
		# is_expression() INLINE bool := V.is_first();
		# expression() INLINE bool := V.first();

		# CONVERT(bool) INLINE NOTYPE! := V;
		# LOG_NOT() INLINE bool := !V;
	}

	SizeofExpression -> Expression
	{
		# FINAL type() ExpressionType := ExpressionType::sizeof;

		Term: TypeOrExpr;

		# is_expression() INLINE bool := Term.is_expression();
		# is_type() INLINE bool := Term.is_type();

		parse(p: Parser&) bool
		{
			IF(!p.consume(tok::Type::sizeof))
				RETURN FALSE;

			t: Trace(&p, "sizeof expression");

			p.expect(tok::Type::parentheseOpen);
			IF(p.consume(tok::Type::hash))
			{
				IF(!(Term := Expression::parse(p)))
					p.fail("expected expression");
			} ELSE
			{
				IF(!(Term := Type::parse(p)))
					p.fail("expected type");
			}

			p.expect(tok::Type::parentheseClose);

			RETURN TRUE;
		}
	}
}