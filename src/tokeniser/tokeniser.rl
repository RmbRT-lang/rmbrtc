INCLUDE "token.rl"
INCLUDE "error.rl"

::rlc::tok
{
	(// Lazy tokeniser. /)
	Tokeniser
	{
		{
			file: src::File #\,
			fileNumber: U1
		}:
			File(file),
			Read(0),
			Start(0),
			Position(0, 0, fileNumber);

		# eof() BOOL := Read == ##File->Contents;
		# position(
			line: UINT \,
			column: UINT \) VOID
		{
			File->position(Read, line, column);
		}

		parse_next(out: Token \) BOOL
		{
			FOR(skipws(); comment(); skipws()){;}

			out->Content.Start := Start := Read;
			out->Position := Position;
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

	PROTECTED:
		File: src::File #\; // The source file.
		Read: src::Index; // The current reading position in the file.
		Start: src::Index; // Start of the current token.
		Position: src::Position;

		STATIC is_idfc(c: CHAR) BOOL :=
			(c >='a' && c<='z')
			|| (c >='A' && c <= 'Z')
			|| (c == '_');
		STATIC is_digit(c: CHAR) BOOL :=
			(c >= '0' && c <= '9');
		STATIC is_alnum(c: CHAR) BOOL :=
			is_digit(c)
			|| is_idfc(c);

		# tok_str() std::[CHAR#]Buffer
			:= File->content(
				src::String(
					Start,
					Read - Start));

		PUBLIC # look() CHAR := look(0);
		# look(ahead: UINT) CHAR
		{
			IF(Read+ahead >= ##File->Contents)
				RETURN 0;
			RETURN File->Contents[Read+ahead];
		}
		getc() CHAR
		{
			IF(Read == ##File->Contents)
				RETURN 0;
			c ::= File->Contents[Read++];
			IF(c == '\n')
			{
				Position.Column := 0;
				Position.Line++;
			} ELSE
				Position.Column++;
			RETURN c;
		}

		skipws() VOID
		{
			c: CHAR;
			WHILE(c := look())
			{
				IF(c == ' '
				|| c == '\t'
				|| c =='\r'
				|| c == '\n')
				{
					getc();
				}
				ELSE
					RETURN;
			}
		}

		eatString(str: CHAR#\) BOOL {
			buf# ::= std::str::buf(str);
			FOR(i ::= 0; i < buf.Size; i++)
				IF(look(i) != buf.Data[i])
					RETURN FALSE;
			Read += buf.Size;
			Position.Column += buf.Size;
			RETURN TRUE;
		}

		# error() VOID
		{
			line: UINT;
			column: UINT;
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

		comment() BOOL
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
					ELSE IF(!getc())
						error();
				}
				RETURN TRUE;
			}
			RETURN FALSE;
		}

		special(out: Token \) BOOL
		{
			STATIC specials: {CHAR#\, Type}#[](
				("+=", :plusEqual),
				("++", :doublePlus),
				("+", :plus),

				("-=", :minusEqual),
				("-:", :minusColon),
				("--", :doubleMinus),
				("->*", :minusGreaterAsterisk),
				("->", :minusGreater),
				("-", :minus),

				("*=", :asteriskEqual),
				("*", :asterisk),

				("\\", :backslash),

				("/=", :forwardSlashEqual),
				("/", :forwardSlash),

				("%=", :percentEqual),
				("%", :percent),

				("!=", :exclamationMarkEqual),
				("!:", :exclamationMarkColon),
				("!", :exclamationMark),

				("^=", :circumflexEqual),
				("^", :circumflex),

				("~:", :tildeColon),
				("~", :tilde),

				("&&&", :tripleAnd),
				("&&=", :doubleAndEqual),
				("&&", :doubleAnd),
				("&=", :andEqual),
				("&", :and),

				("||=", :doublePipeEqual),
				("||", :doublePipe),
				("|=", :pipeEqual),
				("|", :pipe),

				("?", :questionMark),

				("::=", :doubleColonEqual),
				(":=", :colonEqual),
				("::", :doubleColon),
				(":", :colon),
				("@@", :doubleAt),
				("@", :at),
				("...", :tripleDot),
				("..!", :doubleDotExclamationMark),
				("..?", :doubleDotQuestionMark),
				(".*", :dotAsterisk),
				(".", :dot),
				(",", :comma),
				(";", :semicolon),
				("==", :doubleEqual),

				("[", :bracketOpen),
				("]", :bracketClose),
				("{", :braceOpen),
				("}", :braceClose),
				("(", :parentheseOpen),
				(")", :parentheseClose),

				("<<<=", :tripleLessEqual),
				("<<<", :tripleLess),
				("<<=", :doubleLessEqual),
				("<<", :doubleLess),
				("<=", :lessEqual),
				("<>", :lessGreater),
				("<-", :lessMinus),
				("<", :less),

				(">>>=", :tripleGreaterEqual),
				(">>>", :tripleGreater),
				(">>=", :doubleGreaterEqual),
				(">>", :doubleGreater),
				(">=", :greaterEqual),
				(">", :greater),

				("$", :dollar),
				("##", :doubleHash),
				("#", :hash)
			);

			FOR(i ::= 0; i < ##specials; i++)
				IF(eatString(specials[i].(0)))
				{
					out->Type := specials[i].(1);
					RETURN TRUE;
				}

			RETURN FALSE;
		}

		identifier(out: Token \) BOOL
		{
			IF(!is_idfc(look()))
				RETURN FALSE;
			++Read;
			++Position.Column;
			WHILE(is_alnum(look())) (++Read, ++Position.Column);

			STATIC keywords: {CHAR#\, Type}#[](
				("ABSTRACT", :abstract),
				("ASSERT", :assert),
				("BOOL", :bool),
				("BREAK", :break),
				("CASE", :case),
				("CATCH", :catch),
				("CHAR", :char),
				("CONTINUE", :continue),
				("DEFAULT", :default),
				("DESTRUCTOR", :destructor),
				("DO", :do),
				("ELSE", :else),
				("ENUM", :enum),
				("EXTERN", :extern),
				("FALSE", :false),
				("FINAL", :final),
				("FINALLY", :finally),
				("FOR", :for),
				("IF", :if),
				("INCLUDE", :include),
				("INLINE", :inline),
				("INT", :int),
				("MASK", :mask),
				("NULL", :null),
				("NUMBER", :number),
				("OPERATOR", :operator),
				("OVERRIDE", :override),
				("PRIVATE", :private),
				("PROTECTED", :protected),
				("PUBLIC", :public),
				("RETURN", :return),
				("S1", :s1),
				("S2", :s2),
				("S4", :s4),
				("S8", :s8),
				("SIZEOF", :sizeof),
				("SM", :sm),
				("STATIC", :static),
				("SWITCH", :switch),
				("TEST", :test),
				("THIS", :this),
				("THROW", :throw),
				("TRUE", :true),
				("TRY", :try),
				("TYPE", :type),
				("U1", :u1),
				("U2", :u2),
				("U4", :u4),
				("U8", :u8),
				("UCHAR", :uchar),
				("UINT", :uint),
				("UM", :um),
				("UNION", :union),
				("VIRTUAL", :virtual),
				("VOID", :void),
				("WHILE", :while)
			);

			str ::= tok_str();
			FOR(i: UM := 0; i < ##keywords; i++)
				IF(!std::str::cmp(
					str,
					std::str::buf(keywords[i].(0))))
				{
					out->Type := keywords[i].(1);
					RETURN TRUE;
				}
			out->Type := :identifier;
			RETURN TRUE;
		}

		number_literal(out: Token \) BOOL
		{
			IF(eatString("0x")
			|| eatString("0X"))
			{
				out->Type := :numberLiteral;
				FOR(i ::= 0;; i++)
				{
					c ::= look();
					IF(c >= '0' && c <= '9'
					|| c >= 'a' && c <= 'f'
					|| c >= 'A' && c <= 'F')
						getc();
					ELSE IF(!i)
						error();
					ELSE
						RETURN TRUE;
				}
			}

			IF(!is_digit(look()))
				RETURN FALSE;
			++Read;
			WHILE(is_digit(look()))
				++Read;

			out->Type := :numberLiteral;
			RETURN TRUE;
		}

		string(out: Token \) BOOL
		{
			IF(eatString("´"))
			{
				out->Type := :stringTick;
				WHILE(!eatString("´"))
				{
					c ::= getc();
					IF(!c)
						error();
					IF(c == '\\')
						IF(!getc())
							error();
				}
				RETURN TRUE;
			}

			delim #::= look();
			IF(delim != '\'' && delim != '"' && delim != '`')
				RETURN FALSE;

			++Read;
			c: CHAR;
			WHILE((c := getc()) != delim)
			{
				IF(!c) error();
				IF(c == '\\')
					IF(!getc()) error();
			}
			SWITCH(delim)
			{
			CASE '\'':
				{
					out->Type := :stringApostrophe;
					BREAK;
				}
			CASE '"':
				{
					out->Type := :stringQuote;
					BREAK;
				}
			CASE '`':
				{
					out->Type := :stringBacktick;
					BREAK;
				}
			}
			RETURN TRUE;
		}
	}
}