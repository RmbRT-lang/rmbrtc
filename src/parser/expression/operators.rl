::rlc::parser::expression
{
	consume_overloadable_binary_operator(p: Parser &, op: rlc::Operator &) BOOL
	{
		FOR(i ::= 0; i < ##detail::k_groups; i++)
			FOR(j ::= 0; j < detail::k_groups[i].Size; j++)
				IF(detail::k_groups[i].Table[j].(2))
					IF(p.consume(detail::k_groups[i].Table[j].(0)))
					{
						op := detail::k_groups[i].Table[j].(1);
						RETURN TRUE;
					}
		RETURN FALSE;
	}

	consume_overloadable_prefix_operator(p: Parser &, op: rlc::Operator &) BOOL
	{
		FOR(i ::= 0; i < ##detail::k_prefix_ops; i++)
			IF(detail::k_prefix_ops[i].(2))
				IF(p.consume(detail::k_prefix_ops[i].(0)))
				{
					op := detail::k_prefix_ops[i].(1);
					RETURN TRUE;
				}
		RETURN FALSE;
	}

	consume_overloadable_postfix_operator(p: Parser &, op: rlc::Operator &) BOOL
	{
		STATIC k_postfix_ops: {tok::Type, rlc::Operator}#[](
			(:doublePlus, :postIncrement),
			(:doubleMinus, :postDecrement),
			(:exclamationMark, :valueOf));

		FOR(i ::= 0; i < ##k_postfix_ops; i++)
			IF(p.consume(k_postfix_ops[i].(0)))
			{
				op := k_postfix_ops[i].(1);
				RETURN TRUE;
			}
		RETURN FALSE;
	}

	::detail
	{
		BinOpDesc
		{
			[T: TYPE]
			{
				// (token, operator, UserOverloadable)
				table: T! #&,
				leftAssoc: BOOL
			}:
				Table(table!),
				Size(##table),
				LeftAssoc(leftAssoc);

			:single{
				entry: {tok::Type, rlc::Operator, BOOL}#\,
				leftAssoc: BOOL
			}:
				Table(entry),
				Size(1),
				LeftAssoc(leftAssoc);

			Table: {tok::Type, rlc::Operator, BOOL}# \;
			Size: UM;
			LeftAssoc: BOOL;
		}

		k_bind: {tok::Type, rlc::Operator, BOOL}#[](
			// bind operators.
			(:dotAsterisk, :bindReference, FALSE),
			(:minusGreaterAsterisk, :bindPointer, FALSE));

		k_mul: {tok::Type, rlc::Operator, BOOL}#[](
			// multiplicative operators.
			(:percent, :mod, TRUE),
			(:forwardSlash, :div, TRUE),
			(:asterisk, :mul, TRUE));

		k_add: {tok::Type, rlc::Operator, BOOL}#[](
			// additive operators.
			(:minus, :sub, TRUE),
			(:plus, :add, TRUE));

		k_shift: {tok::Type, rlc::Operator, BOOL}#[](
			// bit shift operators.
			(:doubleLess, :shiftLeft, TRUE),
			(:doubleGreater, :shiftRight, TRUE),
			(:tripleLess, :rotateLeft, TRUE),
			(:tripleGreater, :rotateRight, TRUE));

		k_bit: {tok::Type, rlc::Operator, BOOL}#[](
			// bit arithmetic operators.
			(:and, :bitAnd, TRUE),
			(:circumflex, :bitXor, TRUE),
			(:pipe, :bitOr, TRUE));

		k_cmp: {tok::Type, rlc::Operator, BOOL}#[](
			// numeric comparisons.
			(:less, :less, TRUE),
			(:lessEqual, :lessEquals, TRUE),
			(:greater, :greater, TRUE),
			(:greaterEqual, :greaterEquals, TRUE),
			(:doubleEqual, :equals, TRUE),
			(:exclamationMarkEqual, :notEquals, TRUE));

		k_log_and: {tok::Type, rlc::Operator, BOOL}#[](
			// boolean arithmetic.
			(:doubleAnd, :logAnd, TRUE),
			(:doubleAnd, :logAnd, TRUE));

		k_log_or: {tok::Type, rlc::Operator, BOOL}#[](
			(:doublePipe, :logOr, TRUE),
			(:doublePipe, :logOr, TRUE));

		k_stream_feed: {tok::Type, rlc::Operator, BOOL}# :=
			(:lessMinus, :streamFeed, TRUE);

		k_assign: {tok::Type, rlc::Operator, BOOL}#[](
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
			:single(&k_stream_feed, TRUE),
			(k_assign, FALSE));

		precedenceGroups: UM# := ##k_groups;

		// (tok, op, user-overloadable)
		k_prefix_ops: {tok::Type, rlc::Operator, BOOL}#[](
				(:at, :async, FALSE),
				(:doubleAt, :fullAsync, FALSE),
				(:circumflex, :fork, FALSE),
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
	}
}