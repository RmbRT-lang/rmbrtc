INCLUDE "operators.rl"

::rlc::parser::expression::op
{
	parse(p: Parser&) INLINE ast::[Config]Expression-std::Dyn
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

	::op parse_binary(
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

			ret ::= std::heap::[ast::[Config]OperatorExpression]new();
			ret->Op := :conditional;
			ret->Operands += :gc(lhs);
			ret->Operands += :gc(then);
			ret->Operands += :gc(else);
			RETURN ret;
		} ELSE
			RETURN parse_binary_rhs(p, lhs, level);
	}

	::op parse_prefix(p: Parser&) ast::[Config]Expression-std::Dyn
	{
		FOR(i ::= 0; i < ##detail::k_prefix_ops; i++)
			IF(p.consume(detail::k_prefix_ops[i].(0)))
			{
				xp: OperatorExpression-std::Dyn(:create);
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

		IF(p.consume(:visit))
		{
			p.expect(:parentheseOpen);
			visit ::= std::[OperatorExpression]new();
			visit->Op := :visit;
			visit->Operands += :gc(lhs);

			DO(comma ::= FALSE)
			{
				IF(comma)
					p.expect(:comma);
				IF(rhs ::= Expression::parse(p))
					visit->Operands += :gc(rhs);
				ELSE
					p.fail("expected expression");
			} FOR(!p.consume(:parentheseClose); comma := TRUE)

			lhs := visit;
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
					lhs := make_unary(memberAccess[i].(2), &&lhs);
					IF(!p.consume(:braceClose))
					{
						DO()
						{
							IF(arg ::= expression::parse(p))
								<OperatorExpression \>(lhs!)->Operands += &&arg;
							ELSE
								p.fail("expected expression");
						} WHILE(p.consume(:comma))
						p.expect(:braceClose);
					}
				}
				ELSE IF(p.consume(:parentheseOpen))
				{
					IF(index ::= expression::parse(p))
						lhs := OperatorExpression::make_binary(
							memberAccess[i].(3),
							&&lhs,
							&&index);
					ELSE p.fail("expected expression");
					p.expect(:parentheseClose);
				} ELSE IF(p.consume(:tilde))
				{
					lhs := make_unary(memberAccess[i].(4), &&lhs);
				}
				ELSE
				{
					exp: MemberReferenceExpression;
					exp.Object := &&lhs;
					exp.IsArrowAccess := (i != 0);

					IF(!parse_member_reference(p, exp.Member))
						p.fail("expected member name");

					lhs := std::gcdup(&&exp);
				}
				CONTINUE["outer"];
			}
		}

		BREAK;
	}

	RETURN lhs;
}