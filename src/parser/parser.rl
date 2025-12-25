INCLUDE "../tokeniser/tokeniser.rl"
::rlc::ast TYPE LocalPosition := U2;
::rlc::parser
{
	Parser
	{
		Type: ENUM tok::Type[];
		SType: tok::Type[];
		Token: U4;
		Payloads: tok::Payload[];
		Positions: src::Index[];
		File: src::File;

		# match_p(i: U1, type: ENUM tok::Type) BOOL --
			:= Type[i] == type;
		# match_s(i: U1, type: TAGGED tok::Type) BOOL --
			:= Type[i]      == type.(0)
			&& SType[i].EOF == type.(1).EOF;

		consume_p(type: ENUM tok::Type) tok::Type * --
		{
			match ::= match_p(0, type);
			ret ::= SType;
			ret := match ?? ret : NULL;
			Type += match;
			SType += match;
			Token += match;
			= ret;
		}

		consume_s(type: TAGGED tok::Type) tok::Payload * --
		{
			match ::= match_s(0, type);
			ret ::= &Payloads[Token];
			ret := match ?? ret : NULL;
			Type += match;
			SType += match;
			Token += match;
			= ret;
		}

		next() VOID --  { Type++;    SType++;    Token++;    } 
		next2() VOID -- { Type += 2; SType += 2; Token += 2; }

		# match_pp(t1: ENUM tok::Type, t2: ENUM tok::Type) BOOL --
			:= match_p(0, t1) && match_p(1, t2);

		# match_ps(t1: ENUM tok::Type, t2: TAGGED tok::Type) BOOL --
			:= match_p(0, t1) && match_s(1, t2);

		# match_sp(t1: TAGGED tok::Type, t2: ENUM tok::Type) BOOL --
			:= match_s(0, t1) && match_p(1, t2);

		# match_ss(t1: TAGGED tok::Type, t2: TAGGED tok::Type) BOOL --
			:= match_s(0, t1) && match_s(1, t2);

		# peek_p() ENUM tok::Type -- := Type[0];

		# context() CHAR #[]
			:= Ctx
				?? Ctx->Name[]
				: "global scope"[];

		Ctx: Trace *;

		# locals() ast::LocalPosition --
		{
			IF(!LocalCount)
				= 0;
			= LocalCount;
		}

		add_local() ast::LocalPosition
		{
			IF(!LocalCount)
				fail("registering local: Local tracking not configured");
			= ++LocalCount!;
		}

		[A...]
		fail(a: A!&&...) VOID --
			{ term::error(at(0).at(), "parse failure: ", <A!&&>(a)...); }

		# at(offset: S1) src::Position --
			:= <src::Position>(File, Positions[Token+offset]);

		LocalTracker
		{
			P: Parser *;
			{...};
			{&&mv}: P := mv.P { mv.P := NULL; }

			DESTRUCTOR
			{
				IF(P)
					P->LocalCount := NULL;
			}
		}
		/// This function starts tracking local variables 
		track_locals() LocalTracker
		{
			IF(!LocalCount)
			{
				LocalCount := :a(0);
				= &THIS;
			}
			= NULL;
		}

	PRIVATE:
		LocalCount: ast::LocalPosition -std::Opt;
		LocalNames: Identifier[#];
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