INCLUDE "../src/file.rl"

::rlc::tok
{
	ENUM Type
	{
		identifier,
		numberLiteral,
		stringApostrophe,
		stringQuote,
		stringBacktick,
		stringTick,

		// Keywords.
		abstract,
		assert,
		bool,
		break,
		case,
		catch,
		char,
		concept,
		continue,
		default,
		destructor,
		do,
		else,
		enum,
		extern,
		false,
		final,
		finally,
		for,
		if,
		include,
		inline,
		int,
		noinit,
		null,
		number,
		operator,
		override,
		private,
		protected,
		public,
		return,
		sizeof,
		static,
		switch,
		test,
		this,
		throw,
		true,
		try,
		type,
		uint,
		union,
		virtual,
		void,
		while,

		// Non-identifier keywords.
		plusEqual,
		doublePlus,
		plus,

		minusEqual,
		minusColon,
		doubleMinus,
		minusGreaterAsterisk,
		minusGreater,
		minus,

		asteriskEqual,
		asterisk,

		backslash,

		forwardSlashEqual,
		forwardSlash,

		percentEqual,
		percent,

		exclamationMarkEqual,
		exclamationMarkColon,
		exclamationMark,

		circumflexEqual,
		circumflex,

		tildeColon,
		tilde,

		doubleAndEqual,
		doubleAnd,
		andEqual,
		and,

		doublePipeEqual,
		doublePipe,
		pipeEqual,
		pipe,

		questionMark,

		doubleColonEqual,
		colonEqual,
		doubleColon,
		colon,
		doubleAt,
		at,
		tripleDot,
		doubleDotExclamationMark,
		doubleDotQuestionMark,
		dotAsterisk,
		dot,
		comma,
		semicolon,
		doubleEqual,

		bracketOpen,
		bracketClose,
		braceOpen,
		braceClose,
		parentheseOpen,
		parentheseClose,

		tripleLessEqual,
		tripleLess,
		doubleLessEqual,
		doubleLess,
		lessEqual,
		lessGreater,
		lessMinus,
		less,

		tripleGreaterEqual,
		tripleGreater,
		doubleGreaterEqual,
		doubleGreater,
		greaterEqual,
		greater,

		dollar,
		hash
	}

	Token
	{
		Type: tok::Type;
		Content: src::String;

		{} INLINE;
		{
			type: tok::Type,
			content: src::String#&
		}:	Type(type),
			Content(content);
	}
}