INCLUDE "../tokeniser/tokeniser.rl"
::rlc::ast TYPE LocalPosition := U2;
::rlc::parser
{
	Parser
	{
		Hot: tok::TokenHot[];
		Token: U4;
		Payloads: tok::Payload[];
		Positions: src::Index[];
		File: src::File;

		{tokens: tok::FileTokens #&, file: src::File}:
			Hot := tokens.Hots![],
			Payloads := tokens.Payloads![],
			Positions := tokens.Positions![],
			File := file,
			Ctx := NULL;

		# progress() U4 -- := Token;
		# eof() BOOL -- := type() == :EOF;

		# match_p(i: U1, type: ENUM tok::Type) BOOL --
			:= Hot[i].Type == type;
		# match_s(i: U1, type: TAGGED tok::Type) BOOL --
			:= (Hot[i].Type      == type.(0))
			&& (Hot[i].SType.EOF == type.(1).EOF);

		expect_p(type: ENUM tok::Type) tok::Type --
		{
			IF:!(stype ::= consume_p(type))
				THIS.fail("expected ", std::str::enum(type));

			= *stype;
		}
		payload_expect_p(type: ENUM tok::Type) tok::Payload --
		{
			IF:!(payload ::= payload_consume_p(type))
				THIS.fail("expected ", std::str::enum(type));

			= *payload;
		}
		expect_s(type: TAGGED tok::Type) tok::Payload --
		{
			IF:!(payload ::= payload_consume_s(type))
				THIS.fail("expected ", tok::name(type));

			= *payload;
		}

		consume_p(type: ENUM tok::Type) tok::Type * --
		{
			match ::= match_p(0, type);
			ret ::= &Hot->SType;
			ret := match ?? ret : NULL;
			Hot += match;
			Token += match;
			= ret;
		}

		payload_consume_p(type: ENUM tok::Type) tok::Payload * --
		{
			match ::= match_p(0, type);
			ret ::= &Payloads[Token];
			ret := match ?? ret : NULL;
			Hot += match;
			Token += match;
			= ret;
		}

		payload_consume_s(type: TAGGED tok::Type) tok::Payload * --
		{
			match ::= match_s(0, type);
			ret ::= &Payloads[Token];
			ret := match ?? ret : NULL;
			Hot += match;
			Token += match;
			= ret;
		}

		pos_consume_s(type: TAGGED tok::Type) src::Index * --
		{
			match ::= match_s(0, type);
			ret ::= &Positions[Token];
			ret := match ?? ret : NULL;
			Hot += match;
			Token += match;
			= ret;
		}

		skip_braces() VOID --
		{
			IF(!match_s(0, :Punctuation(:braceOpen)))
				fail("Expected braces");
			skip_nesting();
		}

		skip_nesting() VOID -- {
			skip_nesting_until_after_mask(~0);
		}

		skip_nesting_until_after_mask(delim_mask: U4) VOID
		{
			open_mask: U4 := 0;
			open_mask |= <U4>(1) << <U1>(tok::Punctuation::parentheseOpen);
			open_mask |= <U4>(1) << <U1>(tok::Punctuation::braceOpen);
			open_mask |= <U4>(1) << <U1>(tok::Punctuation::bracketOpen);

			close_mask: U4 := 0;
			close_mask |= <U4>(1) << <U1>(tok::Punctuation::parentheseClose);
			close_mask |= <U4>(1) << <U1>(tok::Punctuation::braceClose);
			close_mask |= <U4>(1) << <U1>(tok::Punctuation::bracketClose);

			ASSERT(###tok::Punctuation < 32);

			IF((close_mask >> <U1>(stype().Punctuation)) & (type() == :Punctuation))
				fail("expected nesting to be opened here.");

			start ::= progress();

			PREFETCH_READ &Hot[1*(CACHELINE / SIZEOF(tok::TokenHot))];
			PREFETCH_READ &Hot[2*(CACHELINE / SIZEOF(tok::TokenHot))];
			PREFETCH_READ &Hot[3*(CACHELINE / SIZEOF(tok::TokenHot))];

			nesting ::= 0;
			WHILE(type() != :EOF)
			{
				isPunct ::= (type() == :Punctuation);
				t: U1 := <U1>(stype().Punctuation);
				next();
				nest_diff ::= ((open_mask >> t) & isPunct) - ((close_mask >> t) & isPunct);
				nesting += nest_diff;

				IF(nesting)
					CONTINUE;

				IF((nesting == 0) & ((delim_mask >> t) & isPunct))
					RETURN;

				IF(nesting < 0)
				{
					at ::= <src::Position>(File, Positions[start]).at();
					fail_at(at, "Expected punctuation before nesting level ends");
					RETURN;
				}
			}

			fail_at(
				<src::Position>(File, Positions[start]).at(),
				"Expected nesting to close before end of file");
		}

		[Punctuations...]
		skip_nesting_until_after(punct: Punctuations!...) VOID --
		{
			delim_mask: U4 := 0;
			(delim_mask |= <U4>(1) << <U1>(<tok::Punctuation>(punct)))...;
			
			skip_nesting_until_after_mask(delim_mask);
		}

		next() VOID --  { Hot++;    Token++;    } 
		next2() VOID -- { Hot += 2; Token += 2; }

		# type() ENUM tok::Type -- := Hot->Type;
		# stype() tok::Type -- := Hot->SType;
		# payload() tok::Payload -- := Payloads[Token];

		# match_pp(t1: ENUM tok::Type, t2: ENUM tok::Type) BOOL --
			:= match_p(0, t1) && match_p(1, t2);

		# match_ps(t1: ENUM tok::Type, t2: TAGGED tok::Type) BOOL --
			:= match_p(0, t1) && match_s(1, t2);

		# match_sp(t1: TAGGED tok::Type, t2: ENUM tok::Type) BOOL --
			:= match_s(0, t1) && match_p(1, t2);

		# match_ss(t1: TAGGED tok::Type, t2: TAGGED tok::Type) BOOL --
			:= match_s(0, t1) && match_s(1, t2);


		# context() CHAR #[#]
			:= Ctx
				?? std::str::c(Ctx->Name[])
				: "global scope"[#];

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
		{
			fail_at(at(0).at(), <A!&&>(a)...);
		}

		[A...]
		fail_at(w: WHERE, a: A!&&...) VOID --
		{
			current: TAGGED tok::Type (type(), stype());
			term::error(w,
				<A!&&>(a)..., " in ", context(),
				" at ", tok::name(current));
		}

		# at(offset: S1) src::Position --
			:= <src::Position>(File, Positions[Token+offset]);

		# at_pos(pos: U4) src::Position --
			:= <src::Position>(File, Positions[pos]);

		# here() src::Position -- := <src::Position>(File, Positions[Token]);

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
			name: CHAR#[#]}:
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
		Name: CHAR #[#];
		Prev: Trace *;
	}
}