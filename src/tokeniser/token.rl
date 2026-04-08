INCLUDE "../src/file.rl"
INCLUDE "../identifierPool.rl"

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
		void,
		and,
		or
	}

	ENUM Punctuation
	{
		doubleQuestionMark,
		doubleColonEqual,
		doubleColon,
		colonEqual,
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
		hash
	}

	// parser::Class::DeclMode depends on the relative ordering of this.
	// parser::FunctionFinality depends on the relative ordering of this.
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
		tildeColon,
		tilde,
		tripleAmp,
		doubleHash
	}
	ENUM PostfixOperator {
		questionMark
	}
	ENUM PrefixOrPostfixOperator {
		exclamationMark,
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
		copy_rtti,

		// some special operations
		// saturating addition
		// It would be nicer for the implementation if we could replace them by multi-token sequences, such as: SAT_ADD U8. Then we would have far fewer tokens here. We might even split it up into SAT ADD U8, and SAT SUB U8, etc.. Though then we have more work in the expression parser phase, probably?
		sat_add_u1,
		sat_add_u2,
		sat_add_u4,
		sat_add_u8,
		sat_add_s1,
		sat_add_s2,
		sat_add_s4,
		sat_add_s8,

		sat_sub_u1,
		sat_sub_u2,
		sat_sub_u4,
		sat_sub_u8,
		sat_sub_s1,
		sat_sub_s2,
		sat_sub_s4,
		sat_sub_s8
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
		Normal,
		RawLiteral_1,
		RawLiteral_2,
		RawLiteral_4,
		RawLiteral_8
	}

	// Keep this at or below 16 variants, so that we can store two token types in one byte, for doubled cache efficiency.
	UNION Type {
	*	EOF: U2; // Simplifies parser. Also pads the structure size.
	?	Identifier: rlc::Identifier;
	?	Number: NumberType;
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
			Identifier: Name := "Not an enum";
			tok::NumberType: "Number";
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
		FileLocal: rlc::FileLocalIdentifier;
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