INCLUDE "operators.rl"
INCLUDE "../symbol.rl"

::rlc::parser::expression::op
{
	parse(p: Parser&) ast::[Config]Expression-std::ValOpt INLINE
		:= parse_binary(p, detail::precedenceGroups);

	parse_binary_rhs(
		p: Parser&,
		lhs: ast::[Config]Expression-std::Val,
		level: UINT
	) ast::[Config]Expression-std::ValOpt
	{
		IF(level == 0)
			= &&lhs;

		group ::= &detail::k_groups[level-1];
		FOR(i ::= 0; i < group->Size; i++)
		{
			IF(tok ::= p.consume(group->Table[i].(0)))
			{
				op ::= group->Table[i].(1);
				ret: ast::[Config]OperatorExpression-std::Val := :a(BARE);
				r ::= ret.mut_ptr_ok();
				r->LocalPos := p.locals();
				r->Op := op;
				range ::= lhs->Range;
				r->Operands += &&lhs;
				r->Position := tok->Position;

				IF(group->LeftAssoc)
				{
					// a + b + c
					// (a + b) + c
					IF:!(rhs ::= parse_binary(p, level-1))
						p.fail("expected expression");
					r->Range := range.span(rhs->Range);
					r->Operands += :!(&&rhs);
					= parse_binary_rhs(p, :<>(&&ret), level);
				} ELSE
				{
					// a := b := c
					// a := (b := c)
					IF:!(rhs ::= parse_binary(p, level))
						p.fail("expected expression");

					r->Range := range.span(rhs->Range);
					r->Operands += :!(&&rhs);
					= :cast_val(&&ret);
				}
			}
		}

		= &&lhs;
	}

	parse_binary(
		p: Parser&,
		level: UINT
	) ast::[Config]Expression-std::ValOpt
	{
		IF:!(lhs ::= level
				?? parse_binary(p, level-1)
				: parse_prefix(p))
			= NULL;

		IF(level == detail::precedenceGroups
		&& p.consume(:doubleQuestionMark))
		{
			IF:!(then ::= expression::parse(p))
				p.fail("expected expression");
			op ::= p.expect(:colon);
			IF:!(else ::= expression::parse(p))
				p.fail("expected expression");

			ret: ast::[Config]OperatorExpression-std::Val := :a(BARE);
			r ::= ret.mut_ptr_ok();
			r->LocalPos := p.locals();
			r->Range := lhs->Range.span(else->Range);
			r->Position := op.Position;
			r->Op := :conditional;
			r->Operands += :!(&&lhs);
			r->Operands += :!(&&then);
			r->Operands += :!(&&else);
			= :cast_val(&&ret);
		} ELSE
			= parse_binary_rhs(p, :!(&&lhs), level);
	}

	parse_prefix(p: Parser&) ast::[Config]Expression-std::ValOpt
	{
		FOR(i ::= 0; i < ##detail::k_prefix_ops; i++)
		{
			IF(tok ::= p.consume(detail::k_prefix_ops[i].(0)))
			{
				xp: ast::[Config]OperatorExpression-std::Val := :a(BARE);
				x ::= xp.mut_ptr_ok();
				x->LocalPos := p.locals();
				x->Op := detail::k_prefix_ops[i].(1);
				IF:!(rhs ::= parse_prefix(p))
					p.fail("expected expression");
				x->Operands += :!(&&rhs);
				x->Range := tok->Content.span(x->Operands!.back()->Range);
				x->Position := tok->Position;
				= :cast_val(&&xp);
			}
		}

		= parse_postfix(p);
	}
}

::rlc::parser::expression::op parse_postfix(
	p: Parser&
) ast::[Config]Expression - std::ValOpt
{
	IF:!(lhs ::= parse_atom(p))
		= NULL;

	STATIC postfix: {tok::Type, rlc::Operator}#[](
		(:doublePlus, :postIncrement),
		(:doubleMinus, :postDecrement),
		(:tripleDot, :variadicExpand),
		(:exclamationMark, :valueOf));

	// (tok, opCtor, opVCtor, opTuple, opDtor)
	STATIC memberAccess: {tok::Type, rlc::Operator, rlc::Operator, rlc::Operator, rlc::Operator}#[](
		(:dot, :constructor, :virtualConstructor, :tupleMemberReference, :destructor),
		(:minusGreater, :pointerConstructor, :virtualPointerConstructor, :tupleMemberPointer, :pointerDestructor));

	FOR["outer"](;;)
	{
		FOR(i ::= 0; i < ##postfix; i++)
		{
			IF(tok ::= p.consume(postfix[i].(0)))
			{
				lhs := ast::[Config]OperatorExpression::make_unary(
					postfix[i].(1),
					tok->Position,
					:!(&&lhs));
				lhs.mut_ok().Range := lhs->Range.span(tok->Content);
				CONTINUE["outer"];
			}
		}

		IF(open ::= p.consume(:bracketOpen))
		{
			sub: ast::[Config]OperatorExpression-std::Val := :a(BARE);
			s ::= sub.mut_ptr_ok();
			s->LocalPos := p.locals();
			s->Op := :subscript;
			s->Position := open->Position;
			s->Operands += :!(&&lhs);

			DO()
				s->Operands += expression::parse_x(p);
				WHILE(p.consume(:comma))
			cls ::= p.expect(:bracketClose);

			s->Range := s->Operands!.front()->Range.span(cls.Content);
			lhs := :<>(&&sub);

			CONTINUE["outer"];
		}

		IF(op ::= p.consume(:visit))
		{
			isReflect ::= p.consume(:asterisk);
			p.expect(:parentheseOpen);
			visit: ast::[Config]OperatorExpression-std::Val := :a(BARE);
			v ::= visit.mut_ptr_ok();
			v->LocalPos := p.locals();
			v->Op := isReflect ?? Operator::reflectVisit : Operator::visit;
			v->Position := op->Position;
			v->Operands += :!(&&lhs);

			cls: tok::Token-std::Opt;
			DO(comma ::= FALSE)
			{
				IF(comma)
					p.expect(:comma);
				v->Operands += expression::parse_x(p);
			} FOR(!(cls := p.consume(:parentheseClose)); comma := TRUE)

			v->Range := v->Operands!.front()->Range.span(cls->Content);
			lhs := :cast_val(&&visit);
			CONTINUE["outer"];
		}

		IF(tok ::= p.consume(:parentheseOpen))
		{
			call: ast::[Config]OperatorExpression-std::Val := :a(BARE);
			c ::= call.mut_ptr_ok();
			c->LocalPos := p.locals();
			c->Op := :call;
			c->Operands += :!(&&lhs);
			c->Position := tok->Position;

			cls: rlc::tok::Token - std::Opt;
			FOR(comma ::= FALSE;
				!(cls := p.consume(:parentheseClose));
				comma := TRUE)
			{
				IF(comma)
					p.expect(:comma);
				c->Operands += expression::parse_x(p);
			}

			c->Range := c->Operands!.front()->Range.span(cls->Content);
			lhs := :cast_val(&&call);
			CONTINUE["outer"];
		}

		FOR(i ::= 0; i < ##memberAccess; i++)
		{
			IF(op ::= p.consume(memberAccess[i].(0)))
			{
				IF(tok ::= p.consume(:virtual))
				{
					p.expect(:braceOpen);
					lhs := ast::[Config]OperatorExpression::make_unary(
						memberAccess[i].(2), tok->Position, :!(&&lhs));

					IF:!(cls ::= p.consume(:braceClose))
					{
						DO(lhs_op ::= <ast::[Config]OperatorExpression \>(&*lhs))
							lhs_op->Operands += expression::parse_x(p);
							WHILE(p.consume(:comma))
						cls := :a(p.expect(:braceClose));
					}
					lhs.mut_ok().Range := lhs->Range.span(cls->Content);
				} ELSE IF(tok ::= p.consume(:braceOpen))
				{
					lhs := ast::[Config]OperatorExpression::make_unary(
						memberAccess[i].(1), tok->Position, :!(&&lhs));

					IF:!(cls ::= p.consume(:braceClose))
					{
						DO(lhs_op ::= <ast::[Config]OperatorExpression \>(&*lhs))
							lhs_op->Operands += expression::parse_x(p);
							WHILE(p.consume(:comma))
						cls := :a(p.expect(:braceClose));
					}
					lhs.mut_ok().Range := lhs->Range.span(cls->Content);
				}
				ELSE IF(tok ::= p.consume(:parentheseOpen))
				{
					IF(index ::= expression::parse(p))
						lhs := ast::[Config]OperatorExpression::make_binary(
							memberAccess[i].(3),
							tok->Position,
							:!(&&lhs),
							:!(&&index));
					ELSE p.fail("expected expression");
					cls ::= p.expect(:parentheseClose);
					lhs.mut_ok().Range := lhs->Range.span(cls.Content);
				} ELSE IF(tok ::= p.consume(:tilde))
				{
					lhs := ast::[Config]OperatorExpression::make_unary(
						memberAccess[i].(4), tok->Position, :!(&&lhs));
					lhs.mut_ok().Range := lhs->Range.span(tok->Content);
				}
				ELSE
				{
					exp: ast::[Config]MemberReferenceExpression-std::Val := :a(BARE);
					e ::= exp.mut_ptr_ok();
					e->LocalPos := p.locals();
					e->Object := :!(&&lhs);
					e->IsArrowAccess := (i != 0);
					e->Position := op->Position;

					IF(!symbol::parse_child(p, e->Member))
						p.fail("expected member name");

					e->Range := e->Object->Range.span(e->Member.Name);

					lhs := :cast_val(&&exp);
				}
				CONTINUE["outer"];
			}
		}

		BREAK;
	}

	lhs->Range;
	= &&lhs;
}