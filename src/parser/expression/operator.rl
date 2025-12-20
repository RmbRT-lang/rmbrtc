INCLUDE "operators.rl"

::rlc::parser::expression::op
{
	parse(p: Parser&) Expression-std::Opt INLINE
	{
		lhs ::= parse_binary(p, detail::precedenceGroups -1);
		IF(p.consume(:doubleQuestionMark))
		{
			then ::= expression::parse_x(p);
			p.expect(:colon);
			else ::= expression::parse_x(p);
			args: Expression[3](lhs, then, else);

			lhs := p.Code.operator_expression(:conditional, peek_pos, args[#], lhs, else);
		}
		= lhs;
	}

	parse_binary_rhs(
		p: Parser&,
		lhs: Expression,
		level: UINT
	) Expression-std::Opt
	{
		IF(level == 0)
			= lhs;

		DO()
		{
			op ::= k_binary_op_lut[p.peek()];
			peek_pos ::= p.peek_data();
			IF(op.(0) == :none || op.(1) != level-1)
				= lhs;

			p.next();

			IF:!(rhs ::= parse_binary(p, level - group->LeftAssoc))
				p.fail("expected expression");

			args: Expression[2](lhs, rhs);
			lhs := p.Code.operator_expression(op.(2), peek_pos, args[#], lhs, rhs);
		} WHILE(op->LeftAssoc)

		= lhs;
	}

	parse_binary(
		p: Parser&,
		level: UINT
	) Expression-std::Opt
	{
		IF:!(lhs ::= level ?? parse_binary(p, level-1) : parse_prefix(p))
			= NULL;

		= parse_binary_rhs(p, lhs!, level);
	}

	parse_prefix(p: Parser&) Expression-std::Opt
	{
		peek ::= p.peek();
		pos ::= p.peek_data();

		op ::= k_prefix_op_lut[peek];

		IF(op.(0) == :none)
			= parse_postfix(p);

		p.next();

		IF:!(rhs ::= parse_prefix(p))
			p.fail("expected expression");

		= p.Code.operator_expression_1(op.(1), pos, lhs, lhs, pos);
	}
}

::rlc::parser::expression::op parse_postfix(
	p: Parser&
) ast::[Config]Expression - std::Opt
{
	IF:!(lhs ::= parse_atom(p))
		= NULL;

	// (tok, opCtor, opVCtor, opTuple, opDtor, opMember)
	STATIC memberAccess: {tok::Type, Operator, Operator, Operator, Operator, Operator}#[?](
		(:dot, :constructor, :virtualConstructor, :tupleMemberReference, :destructor, :memberAccess),
		(:minusGreater, :pointerConstructor, :virtualPointerConstructor, :tupleMemberPointer, :pointerDestructor, :pointerMemberAccess));

	FOR["outer"](;;)
	{
		peek ::= p.peek();
		op ::= k_postfix_op_lut[peek];

		IF(op.(0) == :none)
			BREAK;

		args: Expression-std::[std::temp::Local]VecT;
		defer: std::temp::Local::Scope;
		SWITCH!(op.(0))
		{
		:memberAccess: {
			i ::= peek == :minusGreater;
			peek_pos ::= p.peek_data();
			p.next();

			IF(tok ::= p.consume(:virtual))
			{
				p.expect(:braceOpen);
				IF:!(close ::= p.consume(:braceClose))
				{
					x.reserve(16);
					DO()
						args += expression::parse_x(p);
						WHILE(p.consume(:comma))
					close := :a(p.expect(:braceClose));
				}

				lhs := p.Code.operator_expression(
					memberAccess[i].(2),
					tok->Position,
					args!,
					lhs, close);
			} ELSE IF(tok ::= p.consume(:braceOpen))
			{
				IF:!(close ::= p.consume(:braceClose))
				{
					x.reserve(16);
					DO()
						args += expression::parse_x(p);
						WHILE(p.consume(:comma))
					close := :a(p.expect(:braceClose));
				}

				lhs := p.Code.operator_expression(
					memberAccess[i].(1),
					tok->Position,
					args!,
					lhs, close);
			}
			ELSE IF(tok ::= p.consume(:parentheseOpen))
			{
				index ::= expression::parse_x(p);
				lhs := ast::[Config]OperatorExpression::make_binary(
					memberAccess[i].(3),
					tok->Position,
					:!(&&lhs),
					:!(&&index));
				close ::= p.expect(:parentheseClose);
				lhs := p.Code.operator_expression(
					memberAccess[i].(1),
					tok->Position,
					args!,
					lhs, close);
			} ELSE IF(tok ::= p.consume(:tilde))
			{
				lhs := p.Code.operator_expression_1(
					memberAccess[i].(4), tok->Position, lhs, lhs, tok);
			}
			ELSE
			{
				IF:!(member ::= symbol::parse_child(p))
					p.fail("expected member name");

				args: Expression[2](lhs, member);

				lhs := p.Code.operator_expression(
					memberAccess[i].(5), peek_pos, args[#], lhs, member);
			}
		}
		:oneToken: {
			p.next();
			lhs := p.Code.operator_expression_1(op.(1), peek_pos, lhs, lhs, peek_pos);
		}
		:call: {
			p.next();
			IF:!(close ::= p.consume(:parentheseClose))
			{
				args.reserve(8);
				args += expression::parse_x(p);
				WHILE(!(close := p.consume(:parentheseClose)))
				{
					p.expect(:comma);
					args += expression::parse_x(p);
				}
			}
			lhs := p.Code.operator_expression_lhs_multi(
				:call, peek_pos, lhs, args[#], lhs, close);
		}
		:subscript: {
			p.next();
			IF(p.consume(:hash))
			{
				close := p.expect(:parentheseClose);
				lhs := p.Code.operator_expression_1(:sizedSlice, peek_pos, lhs, lhs, close);
			} ELSE IF(close ::= p.consume(:bracketClose))
			{
				lhs := p.Code.operator_expression_1(:unsizedSlice, peek_pos, lhs, lhs, close);
			} ELSE
			{
				args.reserve(4);
				args += expression::parse_x(p);
				WHILE(p.consume(:comma))
					args += expression::parse_x(p);
				close ::= p.expect(:bracketClose);
				lhs := p.Code.operator_expression_lhs_multi(
					:subscript, peek_pos, lhs, args[#], lhs, close);
			}
		}
		:visit: {
			p.next();

			type: Operator := p.consume(:asterisk) ?? :reflectVisit : :visit;
			p.expect(:parentheseOpen);
			IF:!(close ::= p.consume(:parentheseClose))
			{
				args.reserve(8);
				args += expression::parse_x(p);
				WHILE(!(close := p.consume(:parentheseClose)))
				{
					p.expect(:comma);
					args += expression::parse_x(p);
				}
			}
			lhs := p.Code.operator_expression_lhs_multi(
				:call, peek_pos, lhs, args[#], lhs, close);
		}
		:none: DIE "already covered by if";
		}
	}

	= lhs;
}