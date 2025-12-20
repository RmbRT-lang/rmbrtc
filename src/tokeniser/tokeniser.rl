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

			FOR(specials_list_strings) // specials.rl
				token_lut[IT[0]] := :special;
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
			out->Content.Start := Start := Read;
			//out->Position := Position;
			DIE "parsing token";
			FOR(;;)
			{
				next ::= look();
				Read++;
				Column++;

				SWITCH!(case ::= token_lut[next])
				{
				:space: { space(next); CONTINUE; }
				:zero: on_zero(out);
				:nonzero: number_literal(out, next);
				:string_apostrophe, :string_quote, :string_backtick:
				{
					out->Type := <tok::Type>(
						<U1>(case) + (
							<U1>(tok::Type::stringApostrophe) -
							<U1>(Case::string_apostrophe)));
					string(out, next);
				}
				:special: special(out, next);
				:uppercase: keyword(out);
				:identifier: identifier(out);
				:parentheseOpen: on_parenthese_open(out);
				:forwardSlash: on_slash(out);
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

				= TRUE;
			}
		}

	PROTECTED:
		Contents: CHAR #[#];
		Read: src::Index; // The current reading position in the file.
		File: src::File; // The source file.
		Start: src::Index; // Start of the current token.
		Line: U4;
		Column: U4;

		STATIC is_idfc(c: CHAR) BOOL :=
			(c >='a' && c <= 'z')
			|| (c >= 'A' && c <= 'Z')
			|| (c == '_');
		STATIC is_digit(c: CHAR) BOOL :=
			(c >= '0' && c <= '9');
		STATIC is_alnum(c: CHAR) BOOL :=
			is_digit(c)
			|| is_idfc(c);

		# tok_str() CHAR#[#] -- := Contents[FROM Start TO Read]; 

		# here() WHERE --
			:= <WHERE>(src::fileNames[File], Line, Column);

		PUBLIC # look() CHAR := look(0);
		# look(ahead: UINT) CHAR -- := Contents[Read+ahead];

		# look2() U2 -- := *<U2 #*>(<UM>(Contents[]) + Read);
		# look4() U4 -- := *<U4 #*>(<UM>(Contents[]) + Read);
		# char2(v: CHAR[2] #&) U2 -- := *<U2 #*>(<UM>(&v));

		getc() CHAR --
		{
			c ::= Contents[Read++];
			col ::= Column;
			col++;
			nl ::= c == '\n';
			col := nl ?? 1 : col;
			Line += nl;
			= c;
		}

		advance_nows() VOID --
		{
			Read++;
			Column++;
		}

		advance_nows_by(amount: U4) VOID --
		{
			Read += amount;
			Column += amount;
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
			newlines ::= 0;
			last_newline ::= Read - Column;
			is_space: BOOL (NOINIT);
			DO(c ::= last)
			{
				next ::= chars[0];
				is_space := (space_mask >> c) & (c < 64);
				chars += is_space;
				read += is_space;
				last_newline := (c == '\n') ?? read : last_newline;
				newlines += (c == '\n');
				c := next;
			} WHILE(is_space)

			Read := read;
			Column := read - last_newline;
			Line += newlines;
		}

		eat2(v: CHAR[2] #&) BOOL -- {
			IF(look2() == char2(v))
			{
				Read += 2;
				Column += 2;
				= TRUE;
			}
			= FALSE;
		}

		eatString(str: CHAR#[#]) BOOL {
			FOR(str)
				IF(look(IOTA) != IT)
					= FALSE;
			Read += ##str;
			Column += ##str;
			= TRUE;
		}

		# error() VOID
		{
			IF(eof())
				err::unexpected_eof(here());
			ELSE
			{
				ch ::= look();
				IF(std::code::utf8::is_follow(ch))
					err::invalid_char_seq(here());

				len ::= std::code::utf8::size(ch);
				left ::= ##Contents - Read;
				IF(len > left)
					err::invalid_char_seq(here());

				buf: CHAR[4] (NOINIT);
				FOR(i ::= 0; i < len; i++)
					buf[i] := look(i);

				err::unexpected_char(here(), std::code::utf8::point(buf[]));
			}
		}

		on_slash(out: Token \) VOID --
		{
			IF(look() == '/')
			{
				i ::= 1;
				WHILE(look(i) != '\n') { i++; }
				Read += i;
				getc();
			} ELSE
				special(out, '/');
		}
		on_parenthese_open(out: Token \) VOID --
		{
			IF(look() == '/')
			{
				FOR(nest ::= 1; nest;)
				{
					next2 ::= look2();
					next1 ::= <U1>(next2);
					enter ::= next2 == char2("(/");
					leave ::= next2 == char2("/)");

					nest += enter - leave;
					Read += 1 + (enter | leave);
					col ::= Column;
					col += 1 + (enter | leave);
					col := (look() == '\n') ?? 1 : col;
					Column := col;
					Line += next1 == '\n';
				}
				IF(eof()) error();
			} ELSE
				special(out, '(');
		}

		special(out: Token \, char: CHAR) VOID --
		{
			FOR(specials_lut[<U1>(char)])
				IF(look4() & IT.(1) == IT.(0))
				{
					out->Type := IT.(2);
					out->Payload.Enum := IT.(3);
					RETURN;
				}

			error();
		}

		keyword(out: Token \) VOID --
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
				out->Payload.Enum := kw.(1);
			}
			ELSE
				out->Type := :identifier;
		}

		identifier(out: Token \) VOID --
		{
			WHILE(is_alnum(look())) advance_nows();
			out->Type := :identifier;
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
			out->Type := :numberLiteral;
			c ::= getc();
			classify ::= token_lut[c];
			SWITCH(c)
			{
			'x', 'X':
			{
				payload: U8 := 0;
				c ::= hex_digit[<U1>(look())];
				FOR(i ::= 0;; i++)
				{
					nextc ::= hex_digit[<U1>(look(i+1))];
					IF(~c)
					{
						payload <<= 4;
						payload |= c;
						c := nextc;

					} ELSE {
						IF(!i)
							err::msg(here(), "expected digits");
						BREAK;
					}
				}
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
					IF!(~hn) BREAK;
					IF!(~ln) tok::err::msg(here(), "odd number of digits");

					Read += 2; 
					Column += 2;

					number |= <U8>(b) << (8*i);

					advance_nows_by(2);
				}

				IF(!i || i > 8)
					tok::err::msg(here(), "raw hex literal exceeds register size");

				STATIC types: tok::Type[8](
					:raw_literal_1,
					:raw_literal_2,
					BARE, // we might add those later for RISA.
					:raw_literal_4,
					BARE, // we might add those later for RISA.
					BARE, // ?
					BARE, // ?
					:raw_literal_8
				);
				out->Type := types[i-1];
				out->Payload.Number := number;

				IF(POPCNT i != 1)
					tok::err::msg(here(), "raw hex literal must have 1/2/4/8 bytes size");
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
							err::msg(here(), "expected digits");
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
					err::msg(here(), "invalid follow-up character after 0.");
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
			out->Type := :numberLiteral;
			out->Payload.Number := number;
		}

		forward_tick_string(out: Token \) VOID --
		{
			out->Type := :stringTick;
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
}