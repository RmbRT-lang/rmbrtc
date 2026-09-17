INCLUDE "token.rl"
INCLUDE "error.rl"
INCLUDE "keywords.rl"
INCLUDE "specials.rl"

::rlc::tok
{
	TokenHot {
		Type: ENUM tok::Type;
		SType: tok::Type;
	}

	Position {
		Pos: src::Position;
		Length: src::Size;
	}

	FileTokens {
		Hots: TokenHot-std::Vec;
		Payloads: tok::Payload-std::Vec;
		Positions: Position -std::Vec;

		reserve(count: U4) VOID
		{
			Hots.reserve(count);
			Payloads.reserve(count);
			Positions.reserve(count);
		}

		clear_reuse() VOID
		{
			Hots.clear_reuse();
			Payloads.clear_reuse();
			Positions.clear_reuse();
		}

		THIS += (token: tok::Token #&) VOID --
		{
			IF(capacity() == ##THIS) reserve(capacity() * 2);
			std::vec::pushback_ok(
				(Hots,      (token.Type, token.SType)),
				(Payloads,  token.Payload),
				(Positions, (token.Position, token.Length)));
		}

		# ## THIS U4 -- := ##Hots;

		# capacity() U4 -- := Hots.Capacity;

		# view() FileTokenView {
			ret: FileTokenView (NOINIT);

			ret.TokenCount := ##THIS;
			ret.Hots := Hots![];
			ret.Payloads := Payloads![];
			ret.Positions := Positions![];

			= ret;
		}
	}

	FileTokenView {
		TokenCount: U4;
		Hots: TokenHot[];
		Payloads: tok::Payload[];
		Positions: Position[];

		THIS += (token: tok::Token #&) VOID --
		{
			Hots     [TokenCount].Type   := token.Type;
			Hots     [TokenCount].SType  .{ token.SType };
			Payloads [TokenCount]        .{ token.Payload };
			Positions[TokenCount].Pos    := token.Position;
			Positions[TokenCount].Length := token.Length;
			TokenCount++;
		}

		# ## THIS U4 -- := TokenCount;
	}

	TwoTokens {
		Hots: TokenHot[2];
		Payloads: tok::Payload[2];
		Positions: Position[2];

		view() FileTokenView := (0, Hots[], Payloads[], Positions[]);
	}

	(/ currently mandatory latency per token:

		load+classify+switch jump/branch miss, + final branch miss
		= 5 +   5    +     15?                 +     15 ? = 40

		Average token length maybe 4?

		Current cost per byte is around 25. So 40/4 + 15 per byte.

		Sean's:
			6 per byte + 6 per token, with specials being 1 token per byte. So we end up with <= 12 per byte + things like number processing, which should add another 1-2 cycles per byte for numbers. And a final reassembly of 4-6 cycles per token, so 6+6 per token, + 8 per byte, would be <= 20 per byte, and more like 12/3+8 = 12 per byte total.
	/)


	// Currently, we have around 32 cycles per byte in the tokeniser. In single-thread mode, we are around 10%-20% faster, so memory migration between pipeline stages is a bit of a slowdown.
	// We probably cannot avoid the branch miss per token, but since lots of tokens have more than one character, this should only account for maybe ~4 cycles per character, if the average token length is >=4 (including whitespaces and identifier length). What we could also do is to try to make one pre-pass that tries to detect all token boundaries first (start&end of identifiers, start&end of numbers, whitespace spans, etc.), and then group all token spans by their starting character or classification. Afterwards, we can properly parse all tokens separately (for example properly parse :specials, etc.). If we have a branchless way to identify a token span, with maybe exceptions for strings and comments, we should be able to remove the switch structure altogether. A post-pass can then parse all numbers, identifiers, keywords, etc. We should be able to achieve that in just a few cycles per byte, and maybe even organise tokens by their length, so that all identifiers of the same length can be parsed together, and all keywords of the same length, and also all numbers of the same length. We could also try parsing multiple parts of the same file at once, although that would cause problems with strings. But we should at least be able to get twice as fast, maybe more. It might require some advanced techniques in a preprocessing step.
	// Basic idea: look at first character, get a classification for it, and also a mask of characters that are allowed to follow. Then consume characters until a non-follow character is met. Unfortunately, we have to treat / and ( and ', ", `, ´ as special cases. Especially for (, that is a bit unfortunate, since it is so frequently used, but maybe a special workaround for that can be found that makes it less impactful. Additionally, we need to be careful about how to deal with sequences of specials, since they can expand to multiple tokens. Maybe we can resolve those first, and it might give us a chance to not have to do too much shuffling of other tokens. And spaces result in no tokens at all, so that is another pain. But at least we would be able to split the file into sequences of spaces, identifiers, numbers, specials, etc. with relatively few cycles per byte.
	// However, since the phase 1 is currently operating at around 4M lines of code per second, and we probably won't hit 1M lines per second overall compilation speed even without factoring in the phase 1, this could at most give us only small amounts of overall compiler performance improvement. Currently, at most, it could make the phase 1 faster by 2x, before other parts of the phase 1 pipeline would also become a bottleneck. So we could go from ~25% to ~12.5% of our 1M budget, at most. And then we would start to be limited by the source loader. Still, it's something worth trying out.
	// Another thing we could try out is to put all phase-1 tasks into one sequential operation and then duplicate that on multiple cores. However, global ID deduplication is inherently single-threaded, so probably the only thing we could do is combine all prior steps, and all later steps, so (loader, tokeniser, iddedup1) -> iddedup2 -> preparser or something. This way, there would not need to be as many memory migrations between cores, which could scale better. But then we still need around 5 cores at least in order to fully exhaust the SSD's speed. Or we might need something like an uring...
	// Another thing that would help with memory contention would be to have the main thread also execute work instead of busy looping.
	// The simpler workaround for now is to just have two tokeniser threads running, although that makes all other tasks slower, too.
	Tokeniser
	{
		{
			file: src::File,
			contents: CHAR#[#],
			offset: U4
		}:
			File := file,
			Contents := contents,
			Read := offset,
			Start := offset;

		# eof() BOOL := Read >= ##Contents;
		# past_eof() BOOL := Read > ##Contents;

		ENUM Cfg {
		?	dummy,
			track_time
		}

		// Classifying the first character of a token.
		ENUM FirstCase {
			eof,
			string_quote, // Strings must have same order as token types
			string_apostrophe,
			string_backtick,
			zero,
			nonzero,
			identifier,
			uppercase,
			special,
			space,
			newline,
			parentheseOpen, // for (/ comments
			forwardSlash, // for // comments.
			other
		}

		// [on_zero().A] requires this order to be exactly as it is.
		ENUM DigitCase {
			binary,
			octal,
			decimal,
			hex
		}

		// For numbers starting with 0.
		ENUM NumberCase {
			hex,
			raw, // How to define a raw literal's semantics? Is it just a memory-ordered sequence of big-endian hex bytes?
			binary,
			octal
		}

		ENUM StringSpecial {
			backspace,
			quote,
			apostrophe
		}

		// Classifying all characters within a token. Stored as flag bits, so that we can do mask & popcnt to quickly count sequences matching a case.
		// Specials (operators, etc.) remain uncategorised. EOF is not represented.
		ENUM FollowCase {
			sig0, // lowest two bits are an enum.
			sig1,
			// Cases that use the enum (mutually exclusive with each other):
			numberCaseSig,
			stringSpecialSig, // enum: \, ", '
			digitCaseSig, // CAUTION [FollowCase.A]: comes late in the enum so that the word mask will cover the first 4 bits (so that hexadecimal digits can be masked properly). SEE [on_zero().B].
			whitespaceSig, // sig0: whether it is a newline.
			// Cases that do not use the enum (not exclusive with other cases):
			idfollow, // mixedcase, numbers, underscores. Cannot use enum.
			keywordcase // uppercase and/or number and/or underscore. Cannot use enum. IMPORTANT: must come after idfollow, SEE [keyword().KW].
		}

		STATIC token_lut: @(CACHELINE) Tokeniser::FirstCase[256] (NOINIT);
		STATIC classifier_lut: @(CACHELINE) U1[256] (NOINIT);

		STATIC init() VOID
		{
			Tokeniser::init_token_lut();
			Tokeniser::init_classifier_lut();
			tok::init_keyword_lut();
			tok::init_specials_lut();
		}

		STATIC init_token_lut() VOID
		{
			FOR(token_lut)
			{
				c: CHAR := IOTA;
				IF(is_digit(c)) IT := :nonzero;
				ELSE IF(is_idfc(c)) IT := (c >= 'A' && c <= 'Z')
					?? FirstCase::uppercase
					: FirstCase::identifier;
				ELSE IT := :other;
			}

			FOR(specials_list) // specials.rl
				token_lut[IT.(0)[0]] := :special;
			token_lut['"'] := :string_quote;
			token_lut['\''] := :string_apostrophe;
			token_lut['`'] := :string_backtick;
			token_lut['('] := :parentheseOpen;
			token_lut['/'] := :forwardSlash;
			token_lut[' '] := :space;
			token_lut['\t'] := :newline;
			token_lut['\n'] := :newline;
			token_lut['\r'] := :newline;
			token_lut['0'] := :zero;
			token_lut[0] := :eof;
		}

		STATIC init_classifier_lut() VOID
		{
			FOR(classifier_lut) IT := 0;


			FOR("abcdefghijklmnopqrstuvwxyz_$0124356789")
				classifier_lut[<U1>(IT)] |= FollowCase::FLAGS(:idfollow);
			FOR("ABCDEFGHIJKLMNOPQRSTUVWXYZ_$0124356789")
				classifier_lut[<U1>(IT)] |= FollowCase::FLAGS(:idfollow, :keywordcase);

			classifier_lut[' ']  := 0 | FollowCase::FLAGS(:whitespaceSig);
			classifier_lut['\t'] := 0 | FollowCase::FLAGS(:whitespaceSig);
			classifier_lut['\n'] := 1 | FollowCase::FLAGS(:whitespaceSig);

			FOR("xX")
				classifier_lut[<U1>(IT)] |=
					<U1>(NumberCase::hex) | FollowCase::FLAGS(:numberCaseSig);
			FOR("rR")
				classifier_lut[<U1>(IT)] |=
					<U1>(NumberCase::raw) | FollowCase::FLAGS(:numberCaseSig);
			FOR("bB")
				classifier_lut[<U1>(IT)] |=
					<U1>(NumberCase::binary) | FollowCase::FLAGS(:numberCaseSig);

			FOR("abcdefABCDEF")
				classifier_lut[<U1>(IT)] |=
					<U1>(DigitCase::hex) | FollowCase::FLAGS(:digitCaseSig);
			FOR("89")
				classifier_lut[<U1>(IT)] |=
					<U1>(DigitCase::decimal) | FollowCase::FLAGS(:digitCaseSig);
			FOR("234567")
				classifier_lut[<U1>(IT)] |=
					<U1>(DigitCase::octal) | FollowCase::FLAGS(:digitCaseSig);
			FOR("01")
				classifier_lut[<U1>(IT)] |=
					<U1>(DigitCase::binary) | FollowCase::FLAGS(:digitCaseSig);
		}

		prepare_file(contents: CHAR# \, classification: U1\, size: U4) VOID
		{
			contentsU2 ::= <U2# \>(contents)[];
			classificationU2 ::= <U2 \>(classification)[];

			size := (size +1) >> 1;
			FOR(i ::= 0; i < size; i++)
			{
				word ::= contentsU2[i];

				c1 ::= classifier_lut[<U1>(word)];
				c2 ::= classifier_lut[<U1>(word >> 8)];

				classificationU2[i] := c1 | (c2 << 8);
			}
		}

		TimingTracker {
			Totals: U8[TABLE FirstCase];
			Counts: U4[TABLE FirstCase];

			add(case: FirstCase, time: U8) VOID --
			{
				IF(time > 2500) RETURN;
				Counts[case]++;
				Totals[case] += time;
			}

			# print() VOID {
				total: U8; FOR(Totals) total += IT;
				total_toks: U8; FOR(Counts) total_toks += IT;

				FOR(Totals)
				{
					dus_time ::= (10*IT) / (CPU_TICK_RATE / MEGA);
					pm_time ::= (1000 * IT) / (total ?? total : 1);
					pm_count ::= (1000 * Counts[IOTA]) / (total_toks ?? total_toks : 1);
					c_per_op ::= (100 * IT) / (Counts[IOTA] ?? Counts[IOTA] : 1);

					pmm_price ::= (MEGA * pm_time) / (pm_count ?? pm_count : 1);

					term::info(NULL,
						std::str::enum(IOTA), ": ", "                   "[FOR 17 - ##std::str::enum(IOTA)],
						std::io::format::dec_x(dus_time / 10, :Pad(4)), ".",
							std::io::format::dec(dus_time % 10), "µs, ",
						std::io::format::dec_x(pm_time / 10, :Pad(3)), ".",
							std::io::format::dec(pm_time % 10), "% time, ",
						std::io::format::dec_x(Counts[IOTA], :Pad(6)), "x, ",
						std::io::format::dec_x(pm_count / 10, :Pad(3)), ".",
							std::io::format::dec(pm_count % 10), "% toks, ",
						std::io::format::dec_x(c_per_op / 100, :Pad(4)), ".",
							std::io::format::dec_x(c_per_op % 100, 2), " ticks/op, ",
						std::io::format::dec_x(pmm_price / 10000, :Pad(3)), ".",
							std::io::format::dec_x((pmm_price % 10000) / 100, 2), "% price");
				}
			}
		}

		parse_next(out: FileTokenView \) BOOL --
			:= parse_all(out, ##*out + 1);

		Timings: TimingTracker;

		parse_all(out: FileTokenView \, capacity: U4) BOOL
		{
			_start_time ::= <Cfg>(Cfg::track_time) ?? CPU_COUNTER : 0;
			FOR(;;)
			{
				next ::= look8();

				// skip a single whitespace if there is one.
				// Around 15% of loop iterations are :space, and almost all of them get eliminated through this trick, which should only cost around 2-3 cycles per token.
				{
				r ::= Read;
				IF#(1){
					skip: BOOL := <U1>(next) == ' ';
					next := skip ?? next >> 8 : next;
					r += skip;
				}

				Start := r;
				Read := ++r;
				}

				case ::= token_lut![<U1>(next)];

				//_start_time ::= <Cfg>(Cfg::track_time) ?? CPU_COUNTER : 0;
				SWITCH!(<U1>(next))
				{
				//:space: { space(); Timings.add(case, CPU_COUNTER-_start_time); CONTINUE; }
				//:space, :newline:
				' ', '\t', '\n', '\r':
				{
					space_multi();
					IF#(<Cfg>(:track_time))
					{
						now ::= CPU_COUNTER;
						Timings.add(case, now-_start_time);
						_start_time := now;
					}
					CONTINUE;
				}
				//:zero:
				'0':
					on_zero(out);
				//:nonzero:
				'1','2','3','4','5','6','7','8','9':
					number_literal(out, next);
				//:string_apostrophe, :string_quote, :string_backtick:
				'\'', '"', '`':
				{
					string(next);
					out->Hots[][##*out] := <TokenHot>(:String, :String(>
							<U1>(<U1>(case) + <S1>(
								<U1>(tok::StringType::StringQuote) -
								<U1>(FirstCase::string_quote)))
						));
					out->Payloads[][##*out].{ :String(Start, Read - Start) };
				}
				//:special:
				'+','-','*','\\','%','!','^','~','&','|','?',':','@','.',',',';','=',
				'[','{',')','}',']',
				'<','>','$','#':
				{ special(out, next); }
				//:uppercase:
				'A','B','C','D','E','F','G','H','I','J','K','L','M','N','O','P','Q','R','S','T','U','V','W','X','Y','Z':
				{ keyword(out, next); }
				//:identifier:
				'a','b','c','d','e','f','g','h','i','j','k','l','m','n','o','p','q','r','s','t','u','v','w','x','y','z','_':
				{ identifier(out); }
				//:parentheseOpen:
				'(':
					{ IF!(on_parenthese_open(out)) CONTINUE; }
				//:forwardSlash:
				'/':
				{ IF!(on_slash(out)) CONTINUE; }
				//:other:
				DEFAULT:
				{
					IF(eat2("´"))
					{
						forward_tick_string(out);
						out->Payloads[][##*out].{ :String(Start, Read - Start) };
					}
					ELSE
					{
						Read := Start;
						error();
					}
				}
				//:eof:
				0:
					{ = FALSE; }
				}
				IF#(<Cfg>(:track_time))
				{
					now ::= CPU_COUNTER;
					Timings.add(case, now - _start_time);
					_start_time := now;
				}


				out->Positions[##*out].Pos := (File, Start);
				out->Positions[##*out].Length := Read - Start;
				out->TokenCount += 1;

				IF(out->TokenCount == capacity)
					= TRUE;
			}
		}

		Classifiers: U1 #[]; // FollowCase::FLAGS
	PROTECTED:
		Contents: CHAR #[#];
		Read: src::Index; // The current reading position in the file.
		File: src::File; // The source file.
		Start: src::Index; // Start of the current token.

		STATIC is_idfc(c: CHAR) BOOL :=
			(c >='a' && c <= 'z')
			|| (c >= 'A' && c <= 'Z')
			|| (c == '_')
			|| (c == '$');
		STATIC is_digit(c: CHAR) BOOL -- :=
			(c >= '0' && c <= '9');
		STATIC is_alnum(c: CHAR) BOOL :=
			is_digit(c)
			|| is_idfc(c);

		# tok_str() CHAR#[#] -- := Contents[][FROM Start UNTIL Read]; 

		PUBLIC # at() WHERE --
			:= <WHERE>(src::fileNames[File], line(), column());

		# line() U4 {
			line: U4 := 1;
			FOR(Contents[][FOR Read])
				line += (IT == '\n');
			= line;
		}
		# column() U4 {
			last_newline: U4 := 0;
			FOR(Contents[][FOR Read])
				last_newline := (IT == '\n') ?? IOTA : last_newline;
			= Read - last_newline;
		}

		PUBLIC # look() CHAR := look_ahead(0);
		# look_ahead(ahead: UINT) CHAR -- := Contents[][Read+ahead];

		# look2() U2 -- := *<U2 #*>(<UM>(<CHAR #*>(Contents[])) + Read);
		# look4() U4 -- := *<U4 #*>(<UM>(<CHAR #*>(Contents[])) + Read);
		# look8() U8 -- := *<U8 #*>(<UM>(<CHAR #*>(Contents[])) + Read);
		# look8_2() {U8, U8} -- := (
			*<U8 #*>(<UM>(<CHAR #*>(Contents[])) + Read),
			*<U8 #*>(<UM>(<CHAR #*>(Contents[])) + Read));
		# look_class() U1 -- := Classifiers[Read];
		# look8_class() U8 -- := *<U8 #*>(<UM>(<VOID #*>(Classifiers)) + Read);
		# look8_class_2() {U8,U8} -- := (
			*<U8 #*>(<UM>(<VOID #*>(Classifiers)) + Read),
			*<U8 #*>(<UM>(<VOID #*>(Classifiers)) + Read + 1));
		# char2(v: CHAR[2] #&) U2 -- := *<U2 #*>(<UM>(&v));

		getc() CHAR -- := Contents[][Read++];

		advance_nows() VOID --
		{
			Read++;
		}

		PUBLIC advance_nows_by(amount: U4) VOID --
		{
			Read += amount;
		}

		space() VOID --
		{
			whitespace_mask: U8# := FollowCase::FLAGS(:whitespaceSig) * 0x0101010101010101;

			c8: U8 (NOINIT);
			cl8: U8 (NOINIT);

			//DO()
			{
				c8 := look8_class();
				cl8 := c8 & whitespace_mask;
			}// FOR(cl8 == whitespace_mask; Read += 8)

			partial_mask ::= FIRST1BIT(whitespace_mask &~ c8) -1;
			Read += POPCNT (cl8 & partial_mask);
		}

		space_multi() VOID --
		{
			whitespace_mask: U8# := FollowCase::FLAGS(:whitespaceSig) * 0x0101010101010101;

			c8: U8 (NOINIT);
			cl8: U8 (NOINIT);

			DO()
			{
				c8 := look8_class();
				cl8 := c8 & whitespace_mask;
			} FOR(cl8 == whitespace_mask; Read += 8)

			partial_mask ::= FIRST1BIT(whitespace_mask &~ c8) -1;
			Read += POPCNT (cl8 & partial_mask);
		}

		eat2(v: CHAR[2] #&) BOOL -- {
			IF(look2() == char2(v))
			{
				Read += 2;
				= TRUE;
			}
			= FALSE;
		}

		eatString(str: CHAR#[#]) BOOL {
			FOR(str)
				IF(look_ahead(IOTA) != IT)
					= FALSE;
			Read += ##str;
			= TRUE;
		}

		# error() VOID
		{
			IF(eof())
				err::unexpected_eof(at());
			ELSE
			{
				ch ::= look();
				IF(std::code::utf8::is_follow(ch))
					err::invalid_char_seq(at());

				len ::= std::code::utf8::size(ch);
				left ::= ##Contents - Read;
				IF(len > left)
					err::invalid_char_seq(at());

				buf: CHAR[4] (NOINIT);
				FOR(i ::= 0; i < len; i++)
					buf[i] := look_ahead(i);

				err::unexpected_char(at(), std::code::utf8::point(buf[]));
			}
		}

		on_slash(out: FileTokenView \) BOOL --
		{
			IF(look() == '/')
			{
				i ::= 1;
				WHILE(look_ahead(i++) != '\n') { ; }
				Read += i;
				= FALSE;
			} ELSE
				special(out, '/');
			= TRUE;
		}
		on_parenthese_open(out: FileTokenView \) BOOL --
		{
			IF(look() == '/')
			{
				++Read;
				FOR(nest ::= 1; nest;)
				{
					next2 ::= look2();
					enter ::= next2 == char2("(/");
					leave ::= next2 == char2("/)");

					nest += enter - leave;
					Read += 1 + (enter | leave);
				}
				IF(past_eof()) error();

				= FALSE;
			} ELSE
				special(out, '(');
			= TRUE;
		}

		special(out: FileTokenView \, next4: U4) VOID --
		{
			FOR(specials_lut[][<U1>(next4)])
				IF(next4 & IT.(1) == IT.(0))
				{
					out->Hots[][##*out] := <TokenHot>(IT.(2), :EOF(IT.(3)));
					Read += (POPCNT(IT.(1)) >> 3) -1;
					RETURN;
				}

			--Read;
			error();
		}

		keyword(out: FileTokenView \, first: CHAR) VOID --
		{
			uppercase ::= TRUE;

			idfollow_mask: U8# := FollowCase::FLAGS(:idfollow) * 0x0101010101010101;
			kwcase_mask: U8# := FollowCase::FLAGS(:keywordcase) * 0x0101010101010101;

			nonKWCase ::= FALSE;
			c8: U8 (NOINIT);
			cl8: U8 (NOINIT);

			DO()
			{
				c8 := look8_class();
				cl8 := c8 & idfollow_mask;
			} FOR(cl8 == idfollow_mask; (Read += 8, nonKWCase |= kwcase_mask &~ c8))

			// [keyword().KW]: partial_mask is all 1-bits until before the first idfollow_mask bit that was not met by cl8. To make this mask valid for keywordcase as well, the idfollow_mask bit must come BEFORE the keywordcase bit, so that both bits have the same value.
			partial_mask ::= FIRST1BIT(idfollow_mask &~ cl8) - 1;
			nonKWCase |= (kwcase_mask &~ c8) & partial_mask;
			Read += POPCNT ( cl8 & partial_mask );

			IF!(nonKWCase)
			{
				kw ::= tok::lookup_keyword(tok_str(), partial_mask);
				out->Hots[##*out] := <TokenHot>(kw.(0), :EOF(kw.(1)));
			}
			ELSE
				out->Hots[##*out] := <TokenHot>(:Identifier, :EOF(0));
		}

		identifier(out: FileTokenView \) VOID --
		{
			allowed_mask: U4# := FirstCase::FLAGS(:zero, :nonzero, :identifier, :uppercase);

			follow_mask: U8# := FollowCase::FLAGS(:idfollow) * 0x0101010101010101;

			cl8: U8 (NOINIT);
			DO()
			{
				c8 ::= look8_class();
				cl8 := c8 & follow_mask;
			} FOR(cl8 == follow_mask; Read += 8)
			Read += POPCNT ( cl8 & (FIRST1BIT(follow_mask &~ cl8) - 1) );
			out->Hots[][##*out] := <TokenHot>(:Identifier, :EOF(0));
		}

		// For non-decimal numbers.
		DigitTableEntry {
			forbidden_digits_mask: U8;
			digit_shift_amounts: U8;
		}
		on_zero(out: FileTokenView \) VOID --
		{
			STATIC k_non_decimal_digit_table: DigitTableEntry[TABLE NumberCase]#(
				// raw literals to have the bytes be in order of the bytes in memory.
				// We deposit digit bits into the highest possible place they can occupy.
				// Then, we shift down to adjust for number of actual digits (except raw).
				:hex    (0x0000000000000000, 0r1c1814100c080400),
				:raw    (0x0000000000000000, 0r04000c0814101c18),
				:binary (0x0303030303030303, 0r0706050403020100),
				:octal  (0x0202020202020202, 0r15120f0c09060300));

			// load the first 8 bytes, also with one skipped.
			cl8_2 ::= look8_class_2();  txt8_2 ::= look8_2();
			first ::= cl8_2.(0);

			number_case: NumberCase := :octal;
			is_special: BOOL := first & FollowCase::FLAGS(:numberCaseSig);
			// Branchlessly select whether to skip the first byte or not, so we do not have two chained loads.
			cl8: U8 := is_special ?? cl8_2.(1) : cl8_2.(0);
			txt8: U8 := is_special ?? txt8_2.(1) : txt8_2.(0);
			Read += is_special;

			// [on_zero().A]: depends on order of DigitCase and NumberCase.
			// hex, raw: 0; binary: (3) octal, decimal, hex; octal: (2) decimal, hex
			digit_mask # ::= <U8>(0x0101010101010101) * FollowCase::FLAGS(:digitCaseSig);


			number_case := is_special ?? <NumberCase>(first & 3) : number_case;

			forbidden_digits_mask # ::=
				k_non_decimal_digit_table[number_case].forbidden_digits_mask;
			digit_shift_amounts ::=
				k_non_decimal_digit_table[number_case].digit_shift_amounts;

			start ::= Read;

			number: U8 (0);

			has_forbidden_digits: U8 := 0;
			forbidden_digits: U8 (NOINIT);
			DO(cl8_: U8 (NOINIT))
			{
				// normalise text to have each byte store the digit value instead of text.
				{
				// Efficiently normalise all digits (incl. hex) to their numerical values.
				// detect all hexademicals.       Turn everything lowercase. Digits unaffected.
				a ::= txt8 & 0x4040404040404040;  txt8 |= 0x2020202020202020;
				// 0x01 for letters, 0x00 for digits.   Normalise digits.
				a >>= 6;                          txt8 -= <U8>('0') * <U8>(0x0101010101010101);
				// 0x80 / 0x7f mask.
				a := <U8>(0x8080808080808080) - a;
				// Mask the adjustment value.
				a &= <U8>(0x0101010101010101) * <U8>('a'-('9'+ 1));
				txt8 -= a; // adjust hexadecimals to 10-15.
				}

				digit_types ::= cl8 & 0x0303030303030303;
				cl8 &= digit_mask;

				partial_mask ::= FIRST1BIT(digit_mask &~ cl8) - 1;
				txt8 &= partial_mask; // NOTE [on_zero().B]: SEE [FollowCase.A].
				forbidden_digits := digit_types & forbidden_digits_mask;
				has_forbidden_digits |= forbidden_digits & partial_mask;

				digit_count ::= POPCNT ( cl8 & partial_mask );
				Read += digit_count;

				// Load next word. That way, the next loop iteration has less of a problem.
				txt8 := look8();
				cl8_ := cl8; cl8 := look8_class();
				
				shamt ::= digit_shift_amounts; word: U8 (NOINIT);

				word := <U8>(<U1>(txt8)) << <U1>(shamt); shamt >>= 8; txt8 >>= 8;
				word |= <U8>(<U1>(txt8)) << <U1>(shamt); shamt >>= 8; txt8 >>= 8;
				word |= <U8>(<U1>(txt8)) << <U1>(shamt); shamt >>= 8; txt8 >>= 8;
				word |= <U8>(<U1>(txt8)) << <U1>(shamt); shamt >>= 8; txt8 >>= 8;
				word |= <U8>(<U1>(txt8)) << <U1>(shamt); shamt >>= 8; txt8 >>= 8;
				word |= <U8>(<U1>(txt8)) << <U1>(shamt); shamt >>= 8; txt8 >>= 8;
				word |= <U8>(<U1>(txt8)) << <U1>(shamt); shamt >>= 8; txt8 >>= 8;
				word |= <U8>(<U1>(txt8)) << <U1>(shamt);

				// If not raw: big endian, shift previous word up by number of bits we added (digits * bits_per_digit), and shift the added digits down to ones.
				// If raw: append word to previous bits. OR: we do a BSWAP at the end and keep the bits as they are. Then, we do not have to do any special logic? So we assemble the words in big-endian. Then we row them together, and then we BSWAP. Unlike hex, we shift by full bit width.

				digit_bits: U1 := 0r04000103 >> (8*<U1>(number_case));
				// NOTE: These shifts are nops for raw literals.
				// shift down the parsed word to its actual worth.
				word >>= (8-digit_count) * digit_bits;
				// shift up the previous contents by the number of bits we added.
				number <<= digit_count * digit_bits;
				// add the parsed word.
				number |= word;

				// If raw literal, the next word simply starts 32 bits higher.
				digit_shift_amounts += (number_case == :raw) * 0x2020202020202020;
			} WHILE(cl8_ == digit_mask)

			// Check number size.
			IF((Read - start) * <U1>(0r04040103 >> (8*<U1>(number_case))) > 64)
				term::error(at(), "number literal exceeds 64 bits");
			IF(number_case == :raw && ((Read-start) & 1))
				term::error(at(), "raw literals must have even digit count");

			// Check for delimeters after the number.
			IF(FollowCase::FLAGS(:idfollow) & <U1>(cl8))
				term::error(at(), "invalid follow-up character after number");

			out->Hots[##*out] := <TokenHot>(:Number, :Number(:Normal));
			out->Payloads[##*out].{ :Number(number) };
		}

		number_literal(out: FileTokenView \, last: CHAR) VOID --
		{
			// TODO: parse in groups of 8, SWAR style, avoiding the loop for almost all instances.

			number: U8 := last - '0';
			next_number ::= number * 10;

			read ::= Read;
			chars # ::= Contents[][FROM read];

			STATIC digits: U8#[?](
				<U8>(1),
				<U8>(10),
				<U8>(100),
				<U8>(1000),
				<U8>(10000),
				<U8>(100000),
				<U8>(1000000),
				<U8>(10000000),
				<U8>(100000000),
				<U8>(1000000000),
				<U8>(10000000000),
				<U8>(100000000000),
				<U8>(1000000000000),
				<U8>(10000000000000),
				<U8>(100000000000000),
				<U8>(1000000000000000),
				<U8>(10000000000000000),
				<U8>(100000000000000000),
				<U8>(1000000000000000000),
				<U8>(10000000000000000000)
			);

			i ::= 0;
			last := (-'0') + chars[0];
			WHILE(<U1>(last) < 10)
			{
				number := next_number + last;
				next_number := number * 10;
				last := (-'0') + chars[++i];
			}

			forbidden_follow: U4# :=
				<U4>(1) << <U1>(FirstCase::identifier) |
				<U4>(1) << <U1>(FirstCase::uppercase);


			IF(i >= 20)
				IF(i > 20 || *chars > '1' || number < <U8>(10000000000000000000))
					term::error(at(), "overflowed integer constant");
			IF(<U4>(1) << <U1>(token_lut![<U1>(last+'0')]) & forbidden_follow)
				term::error(at(), "invalid follow-up character after number");

			Read += i;
			out->Hots[##*out] := <TokenHot>(:Number, :Number(:Normal));
			out->Payloads[##*out].{ :Number(number) };
		}

		forward_tick_string(out: FileTokenView \) VOID --
		{
			out->Hots[##*out] := <TokenHot>(:String, :String(:StringTick));
			WHILE(!eat2("´"))
			{
				IF:!(c ::= getc())
					error();
				IF(c == '\\')
					IF(!getc())
						error();
			}
		}

		string(delim: CHAR) VOID --
		{
			FOR(c ::= getc(); c != delim; c := getc())
			{
				IF(!c) error();
				IF(c == '\\')
					IF(!getc()) error();
			}
		}
	}
}