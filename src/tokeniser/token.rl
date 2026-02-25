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
		export,
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

	ENUM StringType {
		StringQuote, // Keep order in sync with [Tokeniser::Case].
		StringApostrophe,
		StringBacktick,
		StringTick
	}

	ENUM NumberType {
		HexNumber,
		DecNumber,
		BinNumber,
		OctNumber,
		RawLiteral_1,
		RawLiteral_2,
		RawLiteral_4,
		RawLiteral_8
	}

	Number {
		Type: NumberType;
		Length: U1;

		{...};
	}

	// Keep this at or below 16 variants, so that we can store two token types in one byte, for doubled cache efficiency.
	UNION Type {
	*	EOF: U2; // Simplifies parser. Also pads the structure size.
	?	Identifier: U2; // File-local ID
	?	Number: tok::Number;
	?	String: StringType;
	?	AuxKeyword: tok::AuxKeyword;
	?	FlowControl: FlowControlKeyword;
	?	BuiltinType: tok::BuiltinType;
	?	IntrinsicOp: IntrinsicOperatorKeyword;
	?	Declaration: DeclarationKeyword;
	?	AssignmentOp: AssignmentOperator;
	?	BinaryOp: BinaryOperator;
	?	PrefixOp: PrefixOperator;
	?	PrefixOrPostfixOp: PrefixOrPostfixOperator;
	?	PrefixOrBinaryOp: PrefixOrBinaryOperator;
	?	PostfixOp: PostfixOperator;
	?	Punctuation: tok::Punctuation;
	}
	has_secondary_type_f: U2 # :=
		(0 << <U1>(<ENUM Type>(:Identifier))) |
		(0 << <U1>(<ENUM Type>(:Number))) |
		(1 << <U1>(<ENUM Type>(:String))) |
		(1 << <U1>(<ENUM Type>(:AuxKeyword))) |
		(1 << <U1>(<ENUM Type>(:FlowControl))) |
		(1 << <U1>(<ENUM Type>(:BuiltinType))) |
		(1 << <U1>(<ENUM Type>(:IntrinsicOp))) |
		(1 << <U1>(<ENUM Type>(:Declaration))) |
		(1 << <U1>(<ENUM Type>(:AssignmentOp))) |
		(1 << <U1>(<ENUM Type>(:BinaryOp))) |
		(1 << <U1>(<ENUM Type>(:PrefixOp))) |
		(1 << <U1>(<ENUM Type>(:PrefixOrPostfixOp))) |
		(1 << <U1>(<ENUM Type>(:PrefixOrBinaryOp))) |
		(1 << <U1>(<ENUM Type>(:PostfixOp))) |
		(1 << <U1>(<ENUM Type>(:Punctuation)));
	has_secondary_type(tok: ENUM Type) BOOL --
		:= has_secondary_type_f & (1 << <U1>(tok));
	secondary_type(type: ENUM Type, secondary: Type) U2 --
		:= (MASK has_secondary_type(type)) & secondary.EOF;

	NameOfEnum {
		Name: CHAR#[];
		[T] THIS(enum: T! #&) VOID -- {
			TYPE SWITCH STATIC(enum)
			{
			U2: Name := "Not an enum";
			tok::Number: "Number";
			DEFAULT: Name := <CHAR#*>(enum)[];
			}
		}
	}
	name(type: TAGGED Type #&) CHAR#[#]
	{
		SWITCH(type.(0))
		{
		:EOF: = "EOF";
		:Identifier: = "Identifier";
		DEFAULT: = std::str::c(<NameOfEnum>() VISIT>>(type).Name);
		}
	}

	IdPayload {
		Global: U2; // Global version of the identifier, not set by tokeniser.
		// Maybe also export identifier? This will be a bit annoying to do before parsing. Has to be done during parsing, probably. Although we can also make it so that any identifier that is after a "." or "->" or ":" becomes one. Although that is also not quite correct. For :symbols, we'd have to do a separate pass, but for "." and "->", it should be correct. Although it doesn't factor in "::", either. Which for enums would be bad. We have to know whether the identifier we are looking up is a global one or local one. So we have to know whether left of :: is a namespace or not.
	}

	UNION Payload {
		Number: U8;
		Identifier: IdPayload;
		String: TokenStringPayload;
	}

	Token
	{
		Type: ENUM tok::Type;
		SType: tok::Type;
		Length: src::Size;
		Position: src::Position;
		Payload: tok::Payload;

		# at() WHERE -- := Position.at();
		# contents() CHAR#[#] :=
			<src::Span>(Position.byte(), Length).contents(Position.file());

		{...};

		:EOF{}: Type(:EOF) {}
	}
}