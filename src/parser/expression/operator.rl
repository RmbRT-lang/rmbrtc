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
			IF(tok ::= p.consume(group->Table[i].(0)))
			{
				op ::= group->Table[i].(1);
				ret: ast::[Config]OperatorExpression-std::Dyn := :a(BARE);
				ret->Op := op;
				range ::= lhs->Range;
				ret->Operands += &&lhs;
				ret->Position := tok->Position;

				IF(group->LeftAssoc)
				{
					// a + b + c
					// (a + b) + c
					IF:!(rhs ::= parse_binary(p, level-1))
						p.fail("expected expression");
					ret->Range := range.span(rhs->Range);
					ret->Operands += &&rhs;
					= parse_binary_rhs(p, &&ret, level);
				} ELSE
				{
					// a := b := c
					// a := (b := c)
					IF:!(rhs ::= parse_binary(p, level))
						p.fail("expected expression");

					ret->Range := range.span(rhs->Range);
					ret->Operands += &&rhs;
					= &&ret;
				}
			}
		}

		= &&lhs;
	}

	parse_binary(
		p: Parser&,
		level: UINT) ast::[Config]Expression-std::Dyn
	{
		IF:!(lhs ::= level
				? parse_binary(p, level-1)
				: parse_prefix(p))
			= NULL;

		IF(level == detail::precedenceGroups
		&& p.consume(:questionMark))
		{
			then ::= expression::parse(p);
			op ::= p.expect(:colon);
			else ::= expression::parse(p);

			ret: ast::[Config]OperatorExpression-std::Dyn := :a(BARE);
			ret->Range := lhs->Range.span(else->Range);
			ret->Position := op.Position;
			ret->Op := :conditional;
			ret->Operands += &&lhs;
			ret->Operands += &&then;
			ret->Operands += &&else;
			= &&ret;
		} ELSE
			= parse_binary_rhs(p, &&lhs, level);
	}

	parse_prefix(p: Parser&) ast::[Config]Expression-std::Dyn
	{
		FOR(i ::= 0; i < ##detail::k_prefix_ops; i++)
		{
			IF(tok ::= p.consume(detail::k_prefix_ops[i].(0)))
			{
				xp: ast::[Config]OperatorExpression-std::Dyn := :a(BARE);
				xp->Op := detail::k_prefix_ops[i].(1);
				xp->Operands += parse_prefix(p);
				xp->Range := tok->Content.span(xp->Operands!.back()->Range);
				xp->Position := tok->Position;
				= xp;
			}
		}

		= parse_postfix(p);
	}
}

::rlc::parser::expression::op parse_postfix(
	p: Parser&) ast::[Config]Expression - std::Dyn
{
	IF:!(lhs ::= parse_atom(p))
		= NULL;

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
				lhs->Range := lhs->Range.span(tok->Content);
				CONTINUE["outer"];
			}
		}

		IF(open ::= p.consume(:bracketOpen))
		{
			sub: ast::[Config]OperatorExpression-std::Dyn := :a(BARE);
			sub->Op := :subscript;
			sub->Position := open->Position;
			sub->Operands += &&lhs;

			DO()
			{
				IF:!(rhs ::= expression::parse(p))
					p.fail("expected expression");
				sub->Operands += &&rhs;
			} WHILE(p.consume(:comma))
			cls ::= p.expect(:bracketClose);

			sub->Range := sub->Operands!.front()->Range.span(cls.Content);
			lhs := &&sub;

			CONTINUE["outer"];
		}

		IF(op ::= p.consume(:visit))
		{
			isReflect ::= p.consume(:asterisk);
			p.expect(:parentheseOpen);
			visit: ast::[Config]OperatorExpression-std::Dyn := :a(BARE);
			visit->Op := isReflect ? Operator::reflectVisit : Operator::visit;
			visit->Position := op->Position;
			visit->Operands += &&lhs;

			cls: tok::Token-std::Opt;
			DO(comma ::= FALSE)
			{
				IF(comma)
					p.expect(:comma);
				IF(rhs ::= expression::parse(p))
					visit->Operands += &&rhs;
				ELSE
					p.fail("expected expression");
			} FOR(!(cls := p.consume(:parentheseClose)); comma := TRUE)

			visit->Range := visit->Operands!.front()->Range.span(cls->Content);
			lhs := &&visit;
			CONTINUE["outer"];
		}

		IF(tok ::= p.consume(:parentheseOpen))
		{
			call: ast::[Config]OperatorExpression-std::Dyn := :a(BARE);
			call->Op := :call;
			call->Operands += &&lhs;
			call->Position := tok->Position;

			cls: tok::Token - std::Opt;
			FOR(comma ::= FALSE;
				!(cls := p.consume(:parentheseClose));
				comma := TRUE)
			{
				IF(comma)
					p.expect(:comma);
				IF(rhs ::= expression::parse(p))
					call->Operands += &&rhs;
				ELSE
					p.fail("expected expression");
			}

			call->Range := call->Operands!.front()->Range.span(cls->Content);
			lhs := &&call;
			CONTINUE["outer"];
		}

		FOR(i ::= 0; i < ##memberAccess; i++)
		{
			IF(op ::= p.consume(memberAccess[i].(0)))
			{
				IF(tok ::= p.consume(:braceOpen))
				{
					lhs := ast::[Config]OperatorExpression::make_unary(
						memberAccess[i].(1), tok->Position, &&lhs);

					IF:!(cls ::= p.consume(:braceClose))
					{
						DO()
						{
							IF(arg ::= expression::parse(p))
								<ast::[Config]OperatorExpression \>(lhs!)->Operands += &&arg;
							ELSE
								p.fail("expected expression");
						} WHILE(p.consume(:comma))
						cls := :a(p.expect(:braceClose));
					}
					lhs->Range := lhs->Range.span(cls->Content);
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
					cls ::= p.expect(:parentheseClose);
					lhs->Range := lhs->Range.span(cls.Content);
				} ELSE IF(tok ::= p.consume(:tilde))
				{
					lhs := ast::[Config]OperatorExpression::make_unary(
						memberAccess[i].(3), tok->Position, &&lhs);
					lhs->Range := lhs->Range.span(tok->Content);
				}
				ELSE
				{
					exp: ast::[Config]MemberReferenceExpression-std::Dyn := :a(BARE);
					exp->Object := &&lhs;
					exp->IsArrowAccess := (i != 0);
					exp->Position := op->Position;

					IF(!symbol::parse_child(p, exp->Member))
						p.fail("expected member name");

					exp->Range := exp->Object->Range.span(exp->Member.Name);

					lhs := &&exp;
				}
				CONTINUE["outer"];
			}
		}

		BREAK;
	}

	lhs->Range;
	= &&lhs;
}