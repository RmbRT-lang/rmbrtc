INCLUDE "../src/file.rl"

::rlc::tok
{
	ENUM Type
	{
		identifier,
		numberLiteral,
		floatLiteral,
		stringApostrophe,
		stringQuote,
		stringBacktick,
		stringTick,

		// Keywords.
		abstract,
		assert,
		bare,
		bool,
		break,
		catch,
		char,
		continue,
		default,
		destructor,
		die,
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
		mask,
		noinit,
		null,
		number,
		override,
		private,
		protected,
		public,
		return,
		s1,
		s2,
		s4,
		s8,
		sizeof,
		sm,
		static,
		switch,
		test,
		this,
		throw,
		true,
		try,
		type,
		u1,
		u2,
		u4,
		u8,
		uchar,
		uint,
		um,
		union,
		virtual,
		visit,
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

		tripleAmp,
		doubleAmpEqual,
		doubleAmp,
		ampEqual,
		amp,

		and,
		or,

		doublePipeEqual,
		doublePipe,
		pipeEqual,
		pipe,

		doubleQuestionMark,
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
		equalGreater,
		equal,

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
		doubleHash,
		hash
	}

	Token
	{
		Type: tok::Type;
		Content: src::String;
		Position: src::Position;

		{...};

		# THIS++ ? {
			IF(Position.File)
				= Position.File!->content(Content)!++;
			= <std::str::CV>()!++;
		}
	}
}