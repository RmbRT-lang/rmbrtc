INCLUDE "token.rl"
INCLUDE "error.rl"
INCLUDE "keywords.rl"
INCLUDE "specials.rl"

::rlc::tok
{
	(// Lazy tokeniser. /)
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
			parentheseOpen, // for (/ comments
			forwardSlash, // for // comments.
			other,
			string_forward_tick // other + 1
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
			token_lut['\t'] := :space;
			token_lut['\n'] := :space;
			token_lut['\r'] := :space;
			token_lut['0'] := :zero;
			token_lut[0] := :eof;
		}

		parse_next(out: Token \) BOOL
		{
			FOR(;;)
			{
				Start := Read;
				out->Position.Pos := (<U4>(File) << 21) | Start;
				next ::= look4();
				Read++;

				SWITCH!(case ::= token_lut[<U1>(next)])
				{
				:space: { space(next); CONTINUE; }
				:zero: on_zero(out);
				:nonzero: number_literal(out, next);
				:string_apostrophe, :string_quote, :string_backtick:
				{
					out->Type := :String;
					out->SType.String := >
						<U1>(<U1>(case) + <S1>(
							<U1>(tok::StringType::StringQuote) -
							<U1>(Case::string_quote)));
					string(out, next);
				}
				:special: special(out, next);
				:uppercase: keyword(out, next);
				:identifier: identifier(out);
				:parentheseOpen: IF!(on_parenthese_open(out)) CONTINUE;
				:forwardSlash: IF!(on_slash(out)) CONTINUE;
				:string_forward_tick: forward_tick_string(out);
				:other:
				{
					IF(eat2("´"))
						forward_tick_string(out);
					ELSE
						error();
				}
				:eof: { = FALSE; }
				}

				out->Length := Read - Start;

				= TRUE;
			}
		}

	PROTECTED:
		Contents: CHAR #[#];
		Read: src::Index; // The current reading position in the file.
		File: src::File; // The source file.
		Start: src::Index; // Start of the current token.

		STATIC is_idfc(c: CHAR) BOOL :=
			(c >='a' && c <= 'z')
			|| (c >= 'A' && c <= 'Z')
			|| (c == '_');
		STATIC is_digit(c: CHAR) BOOL :=
			(c >= '0' && c <= '9');
		STATIC is_alnum(c: CHAR) BOOL :=
			is_digit(c)
			|| is_idfc(c);

		# tok_str() CHAR#[#] -- := Contents[FROM Start UNTIL Read]; 

		PUBLIC # at() WHERE --
			:= <WHERE>(src::fileNames[File], line(), column());

		#line() U4 {
			line: U4 := 1;
			FOR(Contents[FOR Read])
				line += (IT == '\n');
			= line;
		}
		# column() U4 {
			last_newline: U4 := 0;
			FOR(Contents[FOR Read])
				last_newline := (IT == '\n') ?? IOTA : last_newline;
			= Read - last_newline + 1;
		}

		PUBLIC # look() CHAR := look(0);
		# look(ahead: UINT) CHAR -- := Contents[Read+ahead];

		# look2() U2 -- := *<U2 #*>(<UM>(<CHAR #*>(Contents[])) + Read);
		# look4() U4 -- := *<U4 #*>(<UM>(<CHAR #*>(Contents[])) + Read);
		# char2(v: CHAR[2] #&) U2 -- := *<U2 #*>(<UM>(&v));

		getc() CHAR -- := Contents[Read++];

		advance_nows() VOID --
		{
			Read++;
		}

		advance_nows_by(amount: U4) VOID --
		{
			Read += amount;
		}

		space(last: CHAR) VOID --
		{
			space_mask: U8# :=
				<U8>(1) << <U1>(' ')  |
				<U8>(1) << <U1>('\t') |
				<U8>(1) << <U1>('\r') |
				<U8>(1) << <U1>('\n');

			read ::= Read;
			chars ::= Contents[][FROM read];
			last := chars[0];
			is_space: BOOL (NOINIT);
			DO(c ::= last)
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
				IF(look(IOTA) != IT)
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
					buf[i] := look(i);

				err::unexpected_char(at(), std::code::utf8::point(buf[]));
			}
		}

		on_slash(out: Token \) BOOL --
		{
			IF(look() == '/')
			{
				i ::= 1;
				WHILE(look(i) != '\n') { i++; }
				Read += i;
				getc();
				= FALSE;
			} ELSE
				special(out, '/');
			= TRUE;
		}
		on_parenthese_open(out: Token \) BOOL --
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

		special(out: Token \, next4: U4) VOID --
		{
			FOR(specials_lut[<U1>(next4)])
				IF(next4 & IT.(1) == IT.(0))
				{
					out->Type := IT.(2);
					out->SType.EOF := IT.(3);
					Read += (POPCNT(IT.(1)) >> 3) -1;
					RETURN;
				}

			--Read;
			error();
		}

		keyword(out: Token \, first: CHAR) VOID --
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
				out->Type := kw.(0);
				out->SType.EOF := kw.(1);
			}
			ELSE
				out->Type := :Identifier;
		}

		identifier(out: Token \) VOID --
		{
			WHILE(is_alnum(look())) advance_nows();
			out->Type := :Identifier;
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

		on_zero(out: Token \) VOID --
		{
			out->Type := :Number;
			c ::= getc();
			classify ::= token_lut[c];
			SWITCH(c)
			{
			'x', 'X':
			{
				payload: U8 := 0;
				c ::= hex_digit[<U1>(look())];
				i ::= 0;
				FOR(;; i++)
				{
					nextc ::= hex_digit[<U1>(look(i+1))];
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
			}
			'r', 'R':
			{
				number: U8 := 0;
				i ::= 0;
				FOR(;; i++)
				{	// little endian bytes, big-endian nibbles, 1/2/4/8 bytes.
					hn ::= hex_digit[look(0)];
					ln ::= hex_digit[look(1)];

					b ::= (hn << 4) | ln;
					IF!(<U1>(~hn)) BREAK;
					IF!(<U1>(~ln)) tok::err::msg(at(), "odd number of digits");

					Read += 2; 

					number |= <U8>(b) << (8*i);

					advance_nows_by(2);
				}

				IF(!i || i > 8)
					tok::err::msg(at(), "raw hex literal exceeds register size");

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
				out->Type := :Number;
				out->SType.Number := (types[i-1], i);
				out->Payload.Number := number;

				IF(POPCNT i != 1)
					tok::err::msg(at(), "raw hex literal must have 1/2/4/8 bytes size");
			}
			'b', 'B':
			{
				payload: U8 := 0;
				look();
				FOR(i ::= 0;; i++)
				{
					nextc ::= look(1);
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
			}
			'1', '2', '3', '4', '5', '6', '7', '8', '9':
			{
				num: U8 := look(0) - '0';
				advance_nows();
				FOR(c ::= look(0); is_digit(c); c := getc())
				{
					num := (num << 3) | (c - '0');
					advance_nows();
				}
			}
			DEFAULT:
			{
				forbidden_follow: U4# :=
					<U4>(1) << <U1>(Case::zero) |
					<U4>(1) << <U1>(Case::identifier) |
					<U4>(1) << <U1>(Case::uppercase);

				IF(<U4>(1) << <U1>(classify) & forbidden_follow)
					term::error(at(), "invalid follow-up character after 0: '", (&c)[FOR 1], "'");
			}
			}
		}

		number_literal(out: Token \, last: CHAR) VOID --
		{
			number: U8 := last - '0';
			last := look();
			WHILE(is_digit(last))
			{
				number := 10 * number + last - '0';
				last := look(1);
				advance_nows();
			}
			out->Type := :Number;
			out->SType.Number := (:DecNumber, Read - Start);
			out->Payload.Number := number;
		}

		forward_tick_string(out: Token \) VOID --
		{
			out->Type := :String;
			out->SType.String := :StringTick;
			WHILE(!eat2("´"))
			{
				IF:!(c ::= getc())
					error();
				IF(c == '\\')
					IF(!getc())
						error();
			}
		}

		string(out: Token \, delim: CHAR) VOID --
		{
			FOR(c ::= getc(); c != delim; c := getc())
			{
				IF(!c) error();
				IF(c == '\\')
					IF(!getc()) error();
			}
		}
	}

	FileTokens {
		Types: ENUM tok::Type-std::Vec;
		STypes: tok::Type-std::Vec;
		Payloads: tok::Payload-std::Vec;
		Positions: src::Index-std::Vec;

		reserve(count: U4) VOID
		{
			Types.reserve(count);
			STypes.reserve(count);
			Payloads.reserve(count);
			Positions.reserve(count);
		}

		clear_reuse() VOID
		{
			Types.clear_reuse();
			STypes.clear_reuse();
			Payloads.clear_reuse();
			Positions.clear_reuse();
		}

		THIS += (token: tok::Token #&) VOID --
		{
			std::vec::pushback(
				(Types,     token.Type),
				(STypes,    token.SType),
				(Payloads,  token.Payload),
				(Positions, token.Position.byte()));
			(/Types += token.Type;
			STypes += token.SType;
			Payloads += token.Payload;
			Positions += token.Position.byte();/)
		}
	}
}