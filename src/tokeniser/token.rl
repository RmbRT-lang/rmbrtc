INCLUDE "../src/file.rl"

::rlc::tok
{

	ENUM AuxKeyword
	{
		assert,
		bare,
		false,
		include,
		inline,
		noinit,
		null,
		number,
		sizeof,
		this,
		true,
		type,
		visit,
		void
	}

	ENUM Punctuation
	{
		doubleQuestionMark,
		doubleColonEqual,
		doubleColon,
		colon,
		at,
		tripleDot,
		comma,
		semicolon,

		bracketOpen,
		bracketClose,
		braceOpen,
		braceClose,
		parentheseOpen,
		parentheseClose,

		dollar,
		doubleHash,
		hash
	}

	ENUM DeclarationKeyword
	{
		abstract,
		destructor,
		enum,
		extern,
		final,
		mask,
		override,
		private,
		protected,
		public,
		static,
		test,
		union,
		virtual
	}

	ENUM FlowControlKeyword
	{
		break,
		catch,
		continue,
		default,
		die,
		do,
		else,
		equal,
		finally,
		for,
		if,
		return,
		switch,
		throw,
		try,
		while
	}

	ENUM BuiltinType
	{
		bool,
		char,
		s1,
		s2,
		s4,
		s8,
		sm,
		u1,
		u2,
		u4,
		u8,
		uchar,
		uint,
		um,
		int
	}
	ENUM PrefixOperator {
		minusColon,
		backslash,
		exclamationMarkColon,
		exclamationMark,
		tildeColon,
		tilde,
		tripleAmp
	}
	ENUM PostfixOperator {
		questionMark
	}
	ENUM PrefixOrPostfixOperator {
		doublePlus,
		doubleMinus
	}
	ENUM PrefixOrBinaryOperator {
		asterisk,
		plus,
		minus,
		doubleAmp,
		amp
	}

	ENUM BinaryOperator {
		forwardSlash,
		percent,
		and,
		or,
		doublePipe,
		pipe,
		circumflex,
		exclamationMarkEqual,
		dotAsterisk,
		dot,
		tripleGreater,
		doubleGreater,
		minusGreaterAsterisk,
		minusGreater,
		minus,
		plus,
		doubleEqual,
		greaterEqual,
		greater,
		tripleLess,
		doubleLess,
		lessEqual,
		lessGreater,
		less
	}
	ENUM IntrinsicOperatorKeyword
	{
		first0bit,
		last0bit,
		first1bit,
		last1bit,
		bswap,
		popcnt,
		prefetch_read,
		prefetch_write,
		prefetch_data,
		prefetch_code,
		code_changed,
		copy_rtti
	}
	ENUM AssignmentOperator {
		plusEqual,
		minusEqual,
		asteriskEqual,
		forwardSlashEqual,
		percentEqual,
		circumflexEqual,
		doubleAmpEqual,
		ampEqual,
		doublePipeEqual,
		pipeEqual,
		colonEqual,
		tripleLessEqual,
		doubleLessEqual,
		tripleGreaterEqual,
		doubleGreaterEqual
	}
	TokenStringPayload { Start: U4; Length: U4; }

	// We want to reduce the number of entries in this enum and outsource them into smaller, contextually related token enums, so that we get smaller lookup tables.
	// And especially tokens that often behave interchangeably should be grouped into the same group. That way, we can group them together better in one generic behaviour descriptor.
	// If we can keep this down to 15 or 16 entries, does this give us significant benefits anywhere? I guess we could then use a 256 buffer to look up two tokens at once? But it would only really work in aligned pairs or something, so that's not that useful. Or maybe we could look up more tokens than that at once using just a shift and a mask, without multiplying and multiple reads. But then again, what use are 3 or 4 tokens? We only know what we really want when we write the parser, and potentially when we write the IR, and the codegen.

	UNION Type {
		// We can squash multiple cases here into one bucket value.
		Identifier;
		Number;
		StringQuote; // String order needs to match Tokeniser::Case.
		StringApostrophe;
		StringBacktick;
		StringTick;
		RawLiteral_1;
		RawLiteral_2;
		RawLiteral_4;
		RawLiteral_8;
		AuxKeyword: tok::AuxKeyword; Enum: U2; // U2 because we might end up with lots of intrinsics.
		FlowControl: FlowControlKeyword;
		BuiltinType: tok::BuiltinType;
		IntrinsicOp: IntrinsicOperatorKeyword;
		Declaration: DeclarationKeyword;
		AssignmentOp: AssignmentOperator;
		BinaryOp: BinaryOperator;
		PrefixOp: PrefixOperator;
		PrefixOrPostfixOp: PrefixOrPostfixOperator;
		PrefixOrBinaryOp: PrefixOrBinaryOperator;
		PostfixOp: PostfixOperator;
		Punctuation: tok::Punctuation;
	}
	UNION Payload {
		Type: tok::Type;
		Identifier: U2;
		Number: U8;
		String: TokenStringPayload;
	}

	Token
	{
		Type: ENUM tok::Type;
		Content: src::Span;
		Position: src::Position;
		Payload: tok::Payload;

		# at() WHERE -- := Position.at();
		# contents() CHAR#[#] := Content.contents(Position.file());

		# type() TAGGED tok::Type -- {
			ret: TAGGED tok::Type (NOINIT);
			ret.(0) := Type;
			ret.(1) := Payload.Type;
			= ret;
		}

		{...};
	}
}