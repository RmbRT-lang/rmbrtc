INCLUDE "../tokeniser/tokeniser.rl"
::rlc::ast TYPE LocalPosition := U2;
::rlc::parser
{
	Parser
	{
		Hot: tok::TokenHot[];
		Token: U4;
		Payloads: tok::Payload[];
		Positions: tok::Position[];
		File: src::File;

		{tokens: tok::FileTokenView #&, file: src::File}:
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

		pos_consume_s(type: TAGGED tok::Type) src::Position * --
		{
			match ::= match_s(0, type);
			ret ::= &Positions[Token].Pos;
			ret := match ?? ret : NULL;
			Hot += match;
			Token += match;
			= ret;
		}

		consume_s(type: TAGGED tok::Type) BOOL --
		{
			match ::= match_s(0, type);
			Hot += match;
			Token += match;
			= match;
		}
		consume_ss(t0: TAGGED tok::Type, t1: TAGGED tok::Type) BOOL --
		{
			match ::= match_ss(t0, t1);
			Hot += match * 2;
			Token += match * 2;
			= match;
		}

		skip_braces() VOID --
		{
			IF(!match_s(0, :Punctuation(:braceOpen)))
				fail("Expected braces");
			skip_nesting();
		}
		skip_parentheses() VOID --
		{
			IF(!match_s(0, :Punctuation(:parentheseOpen)))
				fail("Expected parentheses");
			skip_nesting();
		}

		skip_nesting() VOID -- {
			skip_nesting_until_after_mask(~0);
		}

		skip_nesting_until_after_mask(delim_mask: U4) tok::Punctuation
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

				IF(nesting > 0)
					CONTINUE;

				IF((nesting == 0) & ((delim_mask >> t) & isPunct))
					RETURN >t;

				IF(nesting < 0)
				{
					fail_pos(start, "Expected punctuation before nesting level ends");
					DIE;
				}
			}

			fail_pos(start,
				"Expected nesting to close before end of file");
			DIE;
		}

		[Punctuations...]
		skip_nesting_until_after(punct: Punctuations!...) tok::Punctuation --
		{
			delim_mask: U4 := 0;
			(delim_mask |= <U4>(1) << <U1>(<tok::Punctuation>(punct)))...;

			= skip_nesting_until_after_mask(delim_mask);
		}

		skip_nesting_until_mask(delim_mask: U4) tok::Punctuation
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
				nest_diff ::= ((open_mask >> t) & isPunct) - ((close_mask >> t) & isPunct);

				IF(nesting > 0)
				{
					nesting += nest_diff;
					next();
					CONTINUE;
				}

				IF((nesting == 0) & ((delim_mask >> t) & isPunct))
					RETURN >t;

				nesting += nest_diff;
				next();

				IF(nesting < 0)
					fail_pos(start, "Expected punctuation before nesting level ends");
			}

			fail_pos(
				start,
				"Expected nesting to close before end of file");
			DIE;
		}

		[Punctuations...]
		skip_nesting_until(punct: Punctuations!...) tok::Punctuation --
		{
			delim_mask: U4 := 0;
			(delim_mask |= <U4>(1) << <U1>(<tok::Punctuation>(punct)))...;
			
			= skip_nesting_until_mask(delim_mask);
		}

		skip_until_nesting_ends_or_mask(delim_mask: U4) tok::Punctuation
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
				RETURN stype().Punctuation;

			start ::= progress();

			PREFETCH_READ &Hot[1*(CACHELINE / SIZEOF(tok::TokenHot))];
			PREFETCH_READ &Hot[2*(CACHELINE / SIZEOF(tok::TokenHot))];
			PREFETCH_READ &Hot[3*(CACHELINE / SIZEOF(tok::TokenHot))];

			nesting ::= 0;
			WHILE(type() != :EOF)
			{
				isPunct ::= (type() == :Punctuation);
				t: U1 := <U1>(stype().Punctuation);
				nest_diff ::= ((open_mask >> t) & isPunct) - ((close_mask >> t) & isPunct);
				nesting += nest_diff;

				IF(nesting > 1)
				{
					next();
					CONTINUE;
				}

				IF((nesting == 0) & ((delim_mask >> t) & isPunct))
					RETURN >t;

				IF(nesting < 0)
					RETURN >t;

				next();
			}

			fail_pos(start,
				"Expected nesting to close before end of file");
			DIE;
		}

		[Punctuations...]
		skip_until_nesting_ends_or(punct: Punctuations!...) tok::Punctuation --
		{
			delim_mask: U4 := 0;
			(delim_mask |= <U4>(1) << <U1>(<tok::Punctuation>(punct)))...;
			
			= skip_until_nesting_ends_or_mask(delim_mask);
		}

		[Punctuations...]
		skip_until_nesting_ends(punct: Punctuations!...) tok::Punctuation --
		{
			= skip_until_nesting_ends_or_mask(0);
		}

		next_if(b: BOOL) VOID -- { Hot += b; Token += b; }
		next() VOID --  { Hot++;    Token++;    } 
		next2() VOID -- { Hot += 2; Token += 2; }

		advance_by(amount: U4) VOID -- { Hot += amount; Token += amount; }

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
		fail_before(a: A!&&...) VOID --
		{
			fail_at(at(-1).at(), <A!&&>(a)...);
		}
		[A...]
		fail_pos(pos: U4, a: A!&&...) VOID --
		{
			fail_at(at_pos(pos).at(), <A!&&>(a)...);
		}

		[A...]
		fail_at(w: WHERE, a: A!&&...) VOID --
		{
			current: TAGGED tok::Type (type(), stype());
			term::error(w,
				<A!&&>(a)..., " in ", context(),
				" at ", tok::name(current));
			DIE;
		}

		# at(offset: S1) src::Position --
			:= Positions[Token+offset].Pos;

		# at_pos(pos: U4) src::Position --
			:= Positions[pos].Pos;

		# here() src::Position -- := Positions[Token].Pos;

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

	TokenSpan {
		File: src::File; Start: U4; End: U4;
		{...} --; {NULL} --; {} -- (NULL);

		# <BOOL> -- := Start != End;
		# ##THIS U4 -- := End - Start;
	}
}