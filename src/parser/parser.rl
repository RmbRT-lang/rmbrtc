INCLUDE "../tokeniser/tokeniser.rl"

::rlc::parser
{
	UNION Peek2 {
		Pair: {TAGGED TokenType, TAGGED TokenType};
		Word: U4;
	}

	Parser
	{
		TokenTypes: TokenType [];
		Tokens: TokenData[];

		consume(t: TokenType) TokenData * --
		{
			match ::= TokenTypes[0] == t;
			ret ::= TokenTypes;
			ret := match ?? ret : NULL;
			Tokens += match;
			TokenTypes += match;
			= ret;
		}

		consume_2(t1: TokenType, t2: TokenType) TokenData[] --
		{
			match := peek_2() == pair(t1, t2);

			ret ::= TokenTypes;
			ret := match ?? ret : NULL;

			Tokens += 2*match;
			TokenTypes += 2*match;

			= ret;
		}

		STATIC pair(t1: TokenType, t2: TokenType) U4 --
			:= <U4>(t1) + <U4>(t2) << 8 * SIZEOF(TokenType);

		# peek_2() U4 --
		{
			IF#(SIZEOF(TokenType) == 1)
				= *<U2*>(&TokenTypes[0]);
			ELSE
				= *<U4*>(&TokenTypes[0]);
		}

		# peek() TokenType -- := TokenTypes[0];

		next() VOID { Tokens++; TokenTypes++; }

		# context() CHAR #\
			:= Ctx
				?? Ctx->Name
				: "global scope";

		Ctx: Trace *;

		locals() ast::LocalPosition
		{
			IF(!Locals)
				= 0;
			= Locals!;
		}

		add_local() ast::LocalPosition
		{
			IF(!Locals)
				fail("registering local: Local tracking not configured");
			= ++Locals!;
		}

		LocalTracker
		{
			P: Parser *;
			{...};
			{&&mv}: P := mv.P { mv.P := NULL; }

			DESTRUCTOR
			{
				IF(P)
					P->Locals := NULL;
			}
		}
		/// This function starts tracking local variables 
		track_locals() LocalTracker
		{
			IF(!Locals)
			{
				Locals := :a(0);
				= &THIS;
			}
			= NULL;
		}
		Cli: ::cli::Console \;
	PRIVATE:
		Locals: ast::LocalPosition -std::Opt;
		Locals: Identifier[#];

		Tokeniser: tok::Tokeniser;
		Buffer: tok::Token[2]; /// Lookahead buffer.
		BufferIndex: UINT;
		BufferSize: UINT;
		Progress: UINT;
		PrevOffset: UINT-std::Opt;
	}

	Trace
	{
		{
			p: Parser \,
			name: CHAR#\}:
			P(p),
			Name(name),
			Prev(p->Ctx)
		{
			P->Ctx := &THIS;
		}

		DESTRUCTOR
		{
			P->Ctx := Prev;
		}

		P: Parser\;
		Name: CHAR #\;
		Prev: Trace *;
	}
}