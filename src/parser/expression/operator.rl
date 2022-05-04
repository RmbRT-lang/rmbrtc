INCLUDE "operators.rl"
INCLUDE "../symbol.rl"

::rlc::parser::expression::op
{
	parse(p: Parser&) ast::[Config]Expression-std::Dyn INLINE
		:= parse_binary(p, detail::precedenceGroups);

	parse_binary_rhs(
		p: Parser&,
		lhs: ast::[Config]Expression-std::Dyn,
		level: UINT
	) ast::[Config]Expression-std::Dyn
	{
		IF(level == 0)
			RETURN &&lhs;

		group ::= &detail::k_groups[level-1];
		FOR(i ::= 0; i < group->Size; i++)
		{
			IF(p.consume(group->Table[i].(0)))
			{
				op ::= group->Table[i].(1);
				ret: ast::[Config]OperatorExpression-std::Dyn := :new;
				ret->Op := op;
				ret->Operands += &&lhs;

				IF(group->LeftAssoc)
				{
					// a + b + c
					// (a + b) + c
					rhs ::= parse_binary(p, level-1);
					IF(!rhs)
						p.fail("expected expression");
					ret->Operands += &&rhs;
					RETURN parse_binary_rhs(p, &&ret, level);
				} ELSE
				{
					// a := b := c
					// a := (b := c)
					rhs ::= parse_binary(p, level);
					IF(!rhs)
						p.fail("expected expression");

					ret->Operands += &&rhs;
					RETURN &&ret;
				}
			}
		}

		RETURN &&lhs;
	}

	parse_binary(
		p: Parser&,
		level: UINT) ast::[Config]Expression-std::Dyn
	{
		lhs ::= level
			? parse_binary(p, level-1)
			: parse_prefix(p);
		IF(!lhs)
			RETURN NULL;

		IF(level == detail::precedenceGroups
		&& p.consume(:questionMark))
		{
			then ::= expression::parse(p);
			p.expect(:colon);
			else ::= expression::parse(p);

			ret: ast::[Config]OperatorExpression-std::Dyn := :new();
			ret->Op := :conditional;
			ret->Operands += :gc(lhs);
			ret->Operands += :gc(then);
			ret->Operands += :gc(else);
			RETURN &&ret;
		} ELSE
			RETURN parse_binary_rhs(p, &&lhs, level);
	}

	parse_prefix(p: Parser&) ast::[Config]Expression-std::Dyn
	{
		FOR(i ::= 0; i < ##detail::k_prefix_ops; i++)
			IF(p.consume(detail::k_prefix_ops[i].(0)))
			{
				xp: ast::[Config]OperatorExpression-std::Dyn := :new();
				xp->Op := detail::k_prefix_ops[i].(1);
				xp->Operands += :gc(parse_prefix(p));
				RETURN xp;
			}

		RETURN parse_postfix(p);
	}
}

::rlc::parser::expression::op parse_postfix(
	p: Parser&) ast::[Config]Expression - std::Dyn
{
	lhs ::= parse_atom(p);
	IF(!lhs)
		RETURN NULL;

	STATIC postfix: {tok::Type, rlc::Operator}#[](
		(:doublePlus, :postIncrement),
		(:doubleMinus, :postDecrement),
		(:tripleDot, :variadicExpand),
		(:exclamationMark, :valueOf));

	// (tok, opCtor, opTuple, opDtor)
	STATIC memberAccess: {tok::Type, rlc::Operator, rlc::Operator, rlc::Operator}#[](
		(:dot, :constructor, :tupleMemberReference, :destructor),
		(:minusGreater, :pointerConstructor, :tupleMemberPointer, :pointerDestructor));

	FOR["outer"](;;)
	{
		FOR(i ::= 0; i < ##postfix; i++)
		{
			IF(tok ::= p.consume(postfix[i].(0)))
			{
				lhs := ast::[Config]OperatorExpression::make_unary(
					postfix[i].(1),
					tok->Position,
					&&lhs);
				CONTINUE["outer"];
			}
		}

		IF(p.consume(:bracketOpen))
		{
			sub: ast::[Config]OperatorExpression-std::Dyn := :new();
			sub->Op := :subscript;
			sub->Operands += &&lhs;

			DO()
			{
				rhs ::= expression::parse(p);
				IF(!rhs)
					p.fail("expected expression");
				sub->Operands += &&rhs;
			} WHILE(p.consume(:comma))
			p.expect(:bracketClose);

			lhs := &&sub;
			CONTINUE["outer"];
		}

		IF(p.consume(:visit))
		{
			p.expect(:parentheseOpen);
			visit: ast::[Config]OperatorExpression-std::Dyn := :new();
			visit->Op := :visit;
			visit->Operands += &&lhs;

			DO(comma ::= FALSE)
			{
				IF(comma)
					p.expect(:comma);
				IF(rhs ::= expression::parse(p))
					visit->Operands += &&rhs;
				ELSE
					p.fail("expected expression");
			} FOR(!p.consume(:parentheseClose); comma := TRUE)

			lhs := &&visit;
			CONTINUE["outer"];
		}

		IF(p.consume(:parentheseOpen))
		{
			call: ast::[Config]OperatorExpression-std::Dyn := :new();
			call->Op := :call;
			call->Operands += &&lhs;

			FOR(comma ::= FALSE;
				!p.consume(:parentheseClose);
				comma := TRUE)
			{
				IF(comma)
					p.expect(:comma);
				IF(rhs ::= expression::parse(p))
					call->Operands += &&rhs;
				ELSE
					p.fail("expected expression");
			}

			lhs := &&call;
			CONTINUE["outer"];
		}

		FOR(i ::= 0; i < ##memberAccess; i++)
		{
			IF(p.consume(memberAccess[i].(0)))
			{
				IF(tok ::= p.consume(:braceOpen))
				{
					lhs := ast::[Config]OperatorExpression::make_unary(
						memberAccess[i].(1), tok->Position, &&lhs);

					IF(!p.consume(:braceClose))
					{
						DO()
						{
							IF(arg ::= expression::parse(p))
								<ast::[Config]OperatorExpression \>(lhs!)->Operands += &&arg;
							ELSE
								p.fail("expected expression");
						} WHILE(p.consume(:comma))
						p.expect(:braceClose);
					}
				}
				ELSE IF(tok ::= p.consume(:parentheseOpen))
				{
					IF(index ::= expression::parse(p))
						lhs := ast::[Config]OperatorExpression::make_binary(
							memberAccess[i].(2),
							tok->Position,
							&&lhs,
							&&index);
					ELSE p.fail("expected expression");
					p.expect(:parentheseClose);
				} ELSE IF(tok ::= p.consume(:tilde))
				{
					lhs := ast::[Config]OperatorExpression::make_unary(
						memberAccess[i].(3), tok->Position, &&lhs);
				}
				ELSE
				{
					exp: ast::[Config]MemberReferenceExpression-std::Dyn := :new();
					exp->Object := &&lhs;
					exp->IsArrowAccess := (i != 0);

					IF(!symbol::parse_child(p, exp->Member))
						p.fail("expected member name");

					lhs := &&exp;
				}
				CONTINUE["outer"];
			}
		}

		BREAK;
	}

	= &&lhs;
}