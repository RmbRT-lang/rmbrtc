::rlc::compiler::ct
{
	// compile time number.
	UNION CTValue {
		Deferred;
	?	Bool: BOOL;
	?	UInt: U8;
	?	SInt: S8;
	?	BuiltinType: tok::BuiltinType; // for casts
	}

	ENUM CTOp {
		Deferred,
	?	Cast,
	?	Operator
	}

	ExpParserState {
		Precedence: U1;
		Lhs: TAGGED CTValue;
	}

	// This parses and evaluates a comptime expression
	parse_eval_expression(
		p: parser::Parser &,
		stack: ExpParserState-std::Vec &,
		file: src::File,
		ns: parser::NamespaceID,
		ms: parser::MemberScopeID) TAGGED CTValue
	{
		nesting: U2;
		lhs: TAGGED CTValue (NOINIT);

		// Parse first value.

		// 1.: skip all opening parentheses.
		WHILE(p.consume_s(:Punctuation(:parentheseOpen))) ++nesting;

		// 2.: expect atom.
		TRY SWITCH(p.type())
		{
		:Number: {
			lhs := p.payload().Number;
			p.next();
		}
		:Identifier: {
			global_name ::= p.stype().Identifier;
			local_name ::= p.payload().Identifier;
			p.next();

			IF(p.consume_s(:Punctuation(:doubleColon)))
			{
				IF(ms)
				{
					decl_id ::= ident::get_
					ms.get_ok()->lookup_inner_v
				}
			} ELSE {
			}
		}
		} CATCH(err: CHAR #\) p.fail("expected expression atom:\n", err);
	}

	parse_eval_binary_expression(p: parser::Parser &) TAGGED CTValue {
	}
}