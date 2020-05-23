INCLUDE "token.rl"
INCLUDE "error.rl"
INCLUDE 'std/pair'

::rlc::tok
{
	(// Lazy tokeniser. /)
	Tokeniser
	{
		CONSTRUCTOR(
			file: src::File #\):
			File(file),
			Read(0),
			BufferIndex(0),
			BufferSize(0),
			Progress(0)
		{
			IF(!parse_next(&Buffer[0]))
				RETURN;
			IF(parse_next(&Buffer[1]))
				BufferSize := 2;
			ELSE
				BufferSize := 1;
		}

		consume(type: Type) bool
			:= consume(type, <Token*>(NULL));

		consume(
			type: Type,
			out: Token *) bool
		{
			IF(match(type))
			{
				consume(out);
				RETURN TRUE;
			}

			RETURN FALSE;
		}

		consume(type: Type, out: src::String \) bool
		{
			token: Token;
			IF(consume(type, &token))
			{
				*out := token.Content;
				RETURN TRUE;
			}
			RETURN FALSE;
		}

		expect(type: Type) VOID
			:= expect(type, <Token *>(NULL));

		expect(type: Type, out: Token *) VOID
		{
			IF(!consume(type, out))
			{
				line: uint;
				column: uint;
				IF(BufferSize)
				{
					File->position(
						Buffer[BufferIndex].Content.Start,
						&line,
						&column);
					THROW ExpectedToken(File, line, column, &Buffer[BufferIndex], type);
				}
				ELSE
				{
					position(&line, &column);
					THROW ExpectedToken(File, line, column, NULL, type);
				}
			}
		}

		expect(type: Type, out: src::String \) VOID
		{
			IF(!consume(type, out))
			{
				error();
			}
		}

		match(type: Type) bool
		{
			IF(!BufferSize)
				RETURN FALSE;

			RETURN Buffer[BufferIndex].Type == type;
		}

		match_ahead(type: Type) bool
		{
			IF(BufferSize != 2)
				RETURN FALSE;

			RETURN Buffer[BufferIndex^1].Type == type;
		}

		consume(out: Token *) bool
		{
			IF(!BufferSize)
				RETURN FALSE;

			IF(out)
				*out := Buffer[BufferIndex];

			IF(!parse_next(&Buffer[BufferIndex]))
				--BufferSize;

			++Progress;
			BufferIndex := BufferIndex ^ 1;

			RETURN TRUE;
		}

		# eof() bool := Read == File->Contents.size();
		# progress() uint := Progress;


	PROTECTED:
		File: src::File #\; // The source file.
		Read: src::Index; // The current reading position in the file.
		Buffer: Token[2]; // Lookahead buffer.
		BufferIndex: ushort;
		BufferSize: ushort;
		Progress: uint;

		STATIC is_idfc(c: char) bool :=
			(c >='a' && c<='z')
			|| (c >='A' && c <= 'Z')
			|| (c == '_');
		STATIC is_digit(c: char) bool :=
			(c >= '0' && c <= '9');
		STATIC is_alnum(c: char) bool :=
			is_digit(c)
			|| is_idfc(c);

		parse_next(out: Token \) bool
		{
			FOR(skipws(); comment(); skipws()){;}

			out->Content.Start := Read;
			IF(identifier(out)
			|| number_literal(out)
			|| string(out)
			|| special(out))
			{
				out->Content.Length := Read - out->Content.Start;
				RETURN TRUE;
			}

			RETURN FALSE;
		}

		# tok_str() std::[char#]Buffer
			:= File->content(
				src::String(
					Buffer[BufferIndex].Content.Start,
					Read - Buffer[BufferIndex].Content.Start));

		PUBLIC # look() char := look(0);
		# look(ahead: uint) char
		{
			IF(Read+ahead >= File->Contents.size())
				RETURN 0;
			RETURN File->Contents.at(Read+ahead);
		}
		getc() char
		{
			IF(Read == File->Contents.size())
				RETURN 0;
			RETURN File->Contents.at(Read++);
		}

		skipws() VOID
		{
			c: char;
			WHILE(c := look())
			{
				IF(c == ' '
				|| c == '\t'
				|| c =='\r'
				|| c == '\n')
					++Read;
				ELSE
					RETURN;
			}
		}

		eatString(str: char#\) bool {
			buf# ::= std::strbuf(str);
			FOR(i ::= 0; i < buf.Size; i++)
				IF(look(i) != buf.Data[i])
					RETURN FALSE;
			Read := Read + buf.Size;
			RETURN TRUE;
		}

		# error() VOID
		{
			line: uint;
			column: uint;
			position(&line, &column);

			IF(eof())
				THROW UnexpectedEOF(
					File,
					line,
					column);
			ELSE
				THROW UnexpectedChar(
					File,
					line,
					column,
					look());
		}

		# position(
			line: uint \,
			column: uint \) VOID
		{
			File->position(Read, line, column);
		}

		comment() bool
		{
			IF(eatString("//"))
			{
				FOR(c ::= getc(); c && c != '\n'; c := getc()) {;}
				RETURN TRUE;
			} ELSE IF(eatString("(/"))
			{
				FOR(nest ::= 1; nest;)
				{
					IF(eatString("(/"))
						++nest;
					IF(eatString("/)"))
						--nest;
					IF(!getc())
						error();
				}
				RETURN TRUE;
			}
			RETURN FALSE;
		}

		special(out: Token \) bool
		{
			STATIC specials: std::[char#\, Type]Pair#[](
				std::pair("+=", Type::plusEqual),
				std::pair("++", Type::doublePlus),
				std::pair("+", Type::plus),

				std::pair("-=", Type::minusEqual),
				std::pair("-:", Type::minusColon),
				std::pair("--", Type::doubleMinus),
				std::pair("->*", Type::minusGreaterAsterisk),
				std::pair("->", Type::minusGreater),
				std::pair("-", Type::minus),

				std::pair("*=", Type::asteriskEqual),
				std::pair("*", Type::asterisk),

				std::pair("\\", Type::backslash),

				std::pair("/=", Type::forwardSlashEqual),
				std::pair("/", Type::forwardSlash),

				std::pair("%=", Type::percentEqual),
				std::pair("%", Type::percent),

				std::pair("!=", Type::exclamationMarkEqual),
				std::pair("!:", Type::exclamationMarkColon),
				std::pair("!", Type::exclamationMark),

				std::pair("^=", Type::circumflexEqual),
				std::pair("^", Type::circumflex),

				std::pair("~:", Type::tildeColon),
				std::pair("~", Type::tilde),

				std::pair("&&=", Type::doubleAndEqual),
				std::pair("&&", Type::doubleAnd),
				std::pair("&=", Type::andEqual),
				std::pair("&", Type::and),

				std::pair("||=", Type::doublePipeEqual),
				std::pair("||", Type::doublePipe),
				std::pair("|=", Type::pipeEqual),
				std::pair("|", Type::pipe),

				std::pair("?", Type::questionMark),

				std::pair("::=", Type::doubleColonEqual),
				std::pair(":=", Type::colonEqual),
				std::pair("::", Type::doubleColon),
				std::pair(":", Type::colon),
				std::pair("@@", Type::doubleAt),
				std::pair("@", Type::at),
				std::pair("...", Type::tripleDot),
				std::pair("..!", Type::doubleDotExclamationMark),
				std::pair("..?", Type::doubleDotQuestionMark),
				std::pair(".*", Type::dotAsterisk),
				std::pair(".", Type::dot),
				std::pair(",", Type::comma),
				std::pair(";", Type::semicolon),
				std::pair("==", Type::doubleEqual),

				std::pair("[", Type::bracketOpen),
				std::pair("]", Type::bracketClose),
				std::pair("{", Type::braceOpen),
				std::pair("}", Type::braceClose),
				std::pair("(", Type::parentheseOpen),
				std::pair(")", Type::parentheseClose),

				std::pair("<<<=", Type::tripleLessEqual),
				std::pair("<<<", Type::tripleLess),
				std::pair("<<=", Type::doubleLessEqual),
				std::pair("<<", Type::doubleLess),
				std::pair("<=", Type::lessEqual),
				std::pair("<", Type::less),

				std::pair(">>>=", Type::tripleGreaterEqual),
				std::pair(">>>", Type::tripleGreater),
				std::pair(">>=", Type::doubleGreaterEqual),
				std::pair(">>", Type::doubleGreater),
				std::pair(">=", Type::greaterEqual),
				std::pair(">", Type::greater),

				std::pair("$", Type::dollar),
				std::pair("#", Type::hash)
			);

			FOR(i ::= 0; i < ::size(specials); i++)
				IF(eatString(specials[i].First))
				{
					out->Type := specials[i].Second;
					RETURN TRUE;
				}

			RETURN FALSE;
		}

		identifier(out: Token \) bool
		{
			IF(!is_idfc(look()))
				RETURN FALSE;
			++Read;
			WHILE(is_alnum(look())) ++Read;

			STATIC keywords: std::[char#\, Type]Pair#[](
				std::pair("ABSTRACT", Type::abstract),
				std::pair("BOOL", Type::bool),
				std::pair("BREAK", Type::break),
				std::pair("CASE", Type::case),
				std::pair("CATCH", Type::catch),
				std::pair("CHAR", Type::char),
				std::pair("CONSTRUCTOR", Type::constructor),
				std::pair("CONTINUE", Type::continue),
				std::pair("DEFAULT", Type::default),
				std::pair("DESTRUCTORr", Type::destructor),
				std::pair("DO", Type::do),
				std::pair("ELSE", Type::else),
				std::pair("ENUM", Type::enum),
				std::pair("EXTERN", Type::extern),
				std::pair("FALSE", Type::false),
				std::pair("FINAL", Type::final),
				std::pair("FINALLY", Type::finally),
				std::pair("FOR", Type::for),
				std::pair("IF", Type::if),
				std::pair("INCLUDE", Type::include),
				std::pair("INLINE", Type::inline),
				std::pair("INT", Type::int),
				std::pair("NUMBER", Type::number),
				std::pair("OPERATOR", Type::operator),
				std::pair("OVERRIDE", Type::override),
				std::pair("PRIVATE", Type::private),
				std::pair("PROTECTED", Type::protected),
				std::pair("PUBLIC", Type::public),
				std::pair("RETURN", Type::return),
				std::pair("SIZEOF", Type::sizeof),
				std::pair("STATIC", Type::static),
				std::pair("SWITCH", Type::switch),
				std::pair("THIS", Type::this),
				std::pair("THROW", Type::throw),
				std::pair("TRUE", Type::true),
				std::pair("TRY", Type::try),
				std::pair("TYPE", Type::type),
				std::pair("UINT", Type::uint),
				std::pair("UNION", Type::union),
				std::pair("VIRTUAL", Type::virtual),
				std::pair("VOID", Type::void),
				std::pair("WHILE", Type::while)
			);

			str ::= tok_str();
			static_assert(__cpp_std::[TYPE(str), std::[char#]Buffer]is_same::value);
			static_assert(__cpp_std::[TYPE(std::strbuf(keywords[0].First)), std::[char#]Buffer]is_same::value);
			FOR(i: std::Size := 0; i < ::size(keywords); i++)
				IF(!std::[]strcmp(
					str,
					std::strbuf(keywords[i].First)))
				{
					out->Type := keywords[i].Second;
					RETURN TRUE;
				}
			out->Type := Type::identifier;
			RETURN TRUE;
		}

		number_literal(out: Token \) bool
		{
			IF(!is_digit(look()))
				RETURN FALSE;
			++Read;
			WHILE(is_digit(look()))
				++Read;

			out->Type := Type::numberLiteral;
			RETURN TRUE;
		}

		string(out: Token \) bool
		{
			delim #::= look();
			IF(delim != '\'' && delim != '"' && delim != '`')
				RETURN FALSE;

			++Read;
			c: char;
			WHILE((c := getc()) != delim)
			{
				IF(c == '\'')
					++Read;
			}
			SWITCH(delim)
			{
			CASE '\'':
				{
					out->Type := Type::stringApostrophe;
					BREAK;
				}
			CASE '"':
				{
					out->Type := Type::stringQuote;
					BREAK;
				}
			CASE '`':
				{
					out->Type := Type::stringBacktick;
					BREAK;
				}
			}
			RETURN TRUE;
		}
	}
}