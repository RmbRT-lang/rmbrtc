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
			contents: CHAR#[#]
		}:
			File := file,
			Contents := contents,
			Read := 0,
			Start := 0;

		# eof() BOOL := Read >= ##Contents;
		# past_eof() BOOL := Read > ##Contents;

		ENUM Case {
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
		STATIC token_lut: @(CACHELINE) Tokeniser::Case[256] (NOINIT);

		STATIC init() VOID
		{
			Tokeniser::init_token_lut();
			Tokeniser::init_hex_digits();
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
					?? Case::uppercase
					: Case::identifier;
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

		parse_next(out: FileTokenView \) BOOL
		{
			FOR(;;)
			{
				Start := Read;
				next ::= look4();
				Read++;
				case ::= token_lut![<U1>(next)];
				SWITCH!(case)
				{
				:newline: { space_multi(); CONTINUE; }
				:space: { space_multi(); CONTINUE; }
				:zero: on_zero(out);
				:nonzero: number_literal(out, next);
				:string_apostrophe, :string_quote, :string_backtick:
				{
					string(next);
					out->Hots[##*out] := <TokenHot>(:String, :String(>
							<U1>(<U1>(case) + <S1>(
								<U1>(tok::StringType::StringQuote) -
								<U1>(Case::string_quote)))
						));
					out->Payloads[##*out].{ :String(Start, Read - Start) };
				}
				:special: { special(out, next); }
				:uppercase: { keyword(out, next); }
				:identifier: { identifier(out); }
				:parentheseOpen:
					{ IF!(on_parenthese_open(out)) CONTINUE; }
				:forwardSlash: { IF!(on_slash(out)) CONTINUE; }
				:other:
				{
					IF(eat2("´"))
					{
						forward_tick_string(out);
						out->Payloads[##*out].{ :String(Start, Read - Start) };
					}
					ELSE
					{
						Read := Start;
						error();
					}
				}
				:eof: { = FALSE; }
				}

				out->Positions[##*out].Pos := (File, Start);
				out->Positions[##*out].Length := Read - Start;
				out->TokenCount += 1;

				= TRUE;
			}
		}

	PROTECTED:
		Contents: CHAR #[#];
		Read: src::Index; // The current reading position in the file.
		File: src::File; // The source file.
		Start: src::Index; // Start of the current token.
		Lines: U4;

		STATIC is_idfc(c: CHAR) BOOL :=
			(c >='a' && c <= 'z')
			|| (c >= 'A' && c <= 'Z')
			|| (c == '_');
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
		# char2(v: CHAR[2] #&) U2 -- := *<U2 #*>(<UM>(&v));

		getc() CHAR -- := Contents[][Read++];

		advance_nows() VOID --
		{
			Read++;
		}

		advance_nows_by(amount: U4) VOID --
		{
			Read += amount;
		}

		space() VOID --
		{
			space_mask: U8# :=
				<U8>(1) << <U1>(' ')  |
				<U8>(1) << <U1>('\t') |
				<U8>(1) << <U1>('\r') |
				<U8>(1) << <U1>('\n');

			read ::= Read;
			chars # ::= Contents[];
			is_space: BOOL (NOINIT);
			c ::= chars[read];
			WHILE((space_mask >> c) & (c < 64))
				c := chars[++read];
			Read := read;
		}

		space_multi() VOID --
		{
			space_mask: U8# :=
				<U8>(1) << <U1>(' ')  |
				<U8>(1) << <U1>('\t') |
				<U8>(1) << <U1>('\r') |
				<U8>(1) << <U1>('\n');

			read ::= Read;
			chars ::= Contents[][FROM read];
			is_space: BOOL (NOINIT);
			DO(c ::= chars[0])
			{
				next ::= chars[1];
				is_space := (space_mask >> c) & (c < 64);
				chars += is_space;
				read += is_space;
				c := next;
			} WHILE(is_space)

			Read := read;
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
					next1 ::= <U1>(next2);
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
			FOR(specials_lut[<U1>(next4)])
				IF(next4 & IT.(1) == IT.(0))
				{
					out->Hots[##*out] := <TokenHot>(IT.(2), :EOF(IT.(3)));
					Read += (POPCNT(IT.(1)) >> 3) -1;
					RETURN;
				}

			--Read;
			error();
		}

		keyword(out: FileTokenView \, first: CHAR) VOID --
		{
			uppercase ::= TRUE;
			FOR(c ::= look(); is_alnum(c); c := look())
			{
				// all non-lowercase identifier characters are before the lowercase characters.
				uppercase &= c < 'a';
				advance_nows();
			}

			IF(uppercase)
			{
				kw ::= tok::lookup_keyword(tok_str());
				out->Hots[##*out] := <TokenHot>(kw.(0), :EOF(kw.(1)));
			}
			ELSE
				out->Hots[##*out] := <TokenHot>(:Identifier, :EOF(0));
		}

		identifier(out: FileTokenView \) VOID --
		{
			allowed_mask: U4# := Case::FLAGS(:zero, :nonzero, :identifier, :uppercase);

			cl8: U4 (NOINIT);
			DO()
			{
				c8 ::= look8();
				cl0 ::=   1 &   ((1*allowed_mask) >> <U1>(token_lut![<U1>(c8)]));
				cl1 ::=   2 &   ((2*allowed_mask) >> <U1>(token_lut![<U1>(c8>>8)]));
				cl2 ::=   4 &   ((4*allowed_mask) >> <U1>(token_lut![<U1>(c8>>16)]));
				cl3 ::=   8 &   ((8*allowed_mask) >> <U1>(token_lut![<U1>(c8>>24)]));
				cl4 ::=  16 &  ((16*allowed_mask) >> <U1>(token_lut![<U1>(c8>>32)]));
				cl5 ::=  32 &  ((32*allowed_mask) >> <U1>(token_lut![<U1>(c8>>40)]));
				cl6 ::=  64 &  ((64*allowed_mask) >> <U1>(token_lut![<U1>(c8>>48)]));
				cl7 ::= 128 & ((128*allowed_mask) >> <U1>(token_lut![<U1>(c8>>56)]));

				cl8 := ((cl0 | cl1) | (cl2 | cl3)) | ((cl4 | cl5) | (cl6 | cl7));
			} FOR(cl8 == 255; Read += 8)
			Read += FIRST0POS cl8;
			out->Hots[##*out] := <TokenHot>(:Identifier, :EOF(0));
		}

		STATIC hex_digit: @(CACHELINE) U1[256] (NOINIT);
		STATIC init_hex_digits() VOID
		{
			hex_digit.{255};
			FOR("0123456789")
				hex_digit[IT] := IOTA;
			FOR("ABCDEF")
				hex_digit[IT] := IOTA + 10;
			FOR("abcdef")
				hex_digit[IT] := IOTA + 10;
		}

		on_zero(out: FileTokenView \) VOID --
		{
			c ::= look();
			classify ::= token_lut[c];
			SWITCH(c)
			{
			'x', 'X':
			{
				advance_nows();
				payload: U8 := 0;
				c ::= hex_digit[<U1>(look())];
				i ::= 0;
				FOR(;; i++)
				{
					nextc ::= hex_digit[<U1>(look_ahead(i+1))];
					IF(<U1>(~c))
					{
						payload <<= 4;
						payload |= c;
						c := nextc;

					} ELSE {
						IF(!i)
							err::msg(at(), "expected digits");
						BREAK;
					}
				}
				Read += i;
				out->Payloads[##*out].{ :Number(payload) };
				out->Hots[##*out] := <TokenHot>(:Number, :Number(:Normal));
			}
			'r', 'R':
			{
				advance_nows();
				number: U8 := 0;
				i ::= 0;
				FOR(;; i++)
				{	// little endian bytes, big-endian nibbles, 1/2/4/8 bytes.
					hn ::= hex_digit[look_ahead(0)];
					ln ::= hex_digit[look_ahead(1)];

					b ::= (hn << 4) | ln;
					IF!(<U1>(~hn)) BREAK;
					IF!(<U1>(~ln)) tok::err::msg(at(), "odd number of digits");

					Read += 2; 

					number |= <U8>(b) << (8*i);

					advance_nows_by(2);
				}

				IF(!i || i > 8)
					tok::err::msg(at(), "raw hex literal exceeds register size: ", std::io::format::dec(i), " bytes > 8");

				STATIC types: tok::NumberType[8](
					:RawLiteral_1,
					:RawLiteral_2,
					BARE, // we might add those later for RISA.
					:RawLiteral_4,
					BARE, // we might add those later for RISA.
					BARE, // ?
					BARE, // ?
					:RawLiteral_8
				);
				out->Hots[##*out] := <TokenHot>(:Number, :Number(types[i-1]));
				out->Payloads[##*out].{ :Number(number) };

				IF(POPCNT i != 1)
					tok::err::msg(at(), "raw hex literal must have 1/2/4/8 bytes size");
			}
			'b', 'B':
			{
				advance_nows();
				payload: U8 := 0;
				look();
				FOR(i ::= 0;; i++)
				{
					nextc ::= look_ahead(1);
					digit: U1 := c - '0';
					IF(digit <= 1)
					{
						advance_nows();
						payload <<= 1;
						payload |= digit;
						c := nextc;
					} ELSE {
						IF(!i)
							err::msg(at(), "expected digits");
						BREAK;
					}
				}
				advance_nows();
				out->Payloads[##*out].{ :Number(payload) };
				out->Hots[##*out] := <TokenHot>(:Number, :Number(:Normal));
			}
			'1', '2', '3', '4', '5', '6', '7', '8', '9':
			{
				num: U8 := look() - '0';
				advance_nows();
				FOR(c ::= look(); is_digit(c); c := getc())
				{
					num := (num << 3) | (c - '0');
					advance_nows();
				}
				out->Hots[##*out] := <TokenHot>(:Number, :Number(:Normal));
				out->Payloads[##*out].{ :Number(num) };
			}
			DEFAULT:
			{
				forbidden_follow: U4# :=
					<U4>(1) << <U1>(Case::zero) |
					<U4>(1) << <U1>(Case::identifier) |
					<U4>(1) << <U1>(Case::uppercase);

				IF(<U4>(1) << <U1>(classify) & forbidden_follow)
					term::error(at(), "invalid follow-up character after 0: '", (&c)[FOR 1], "'");

				out->Hots[##*out] := <TokenHot>(:Number, :Number(:Normal));
				out->Payloads[##*out].{ :Number(0) };
			}
			}
		}

		number_literal(out: FileTokenView \, last: CHAR) VOID --
		{
			number: U8 := last - '0';
			next_number ::= number * 10;

			read ::= Read;
			chars # ::= Contents[][FROM read];

			i ::= 0;
			last := (-'0') + chars[0];
			WHILE(<U1>(last) < 10)
			{
				number := next_number + last;
				next_number := number * 10;
				last := (-'0') + chars[++i];
			}

			forbidden_follow: U4# :=
				<U4>(1) << <U1>(Case::identifier) |
				<U4>(1) << <U1>(Case::uppercase);

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

			IF(i >= ##digits || number < digits![i])
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