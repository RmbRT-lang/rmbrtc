INCLUDE "../tokeniser/tokeniser.rl"
INCLUDE "error.rl"
INCLUDE 'std/tags'

::rlc::parser
{
	Parser
	{
		std::NoCopy;
		std::NoMove;

		{
			file: src::File #\
		}:
			File(file),
			Tokeniser(file),
			Ctx(NULL),
			Buffer(NOINIT),
			BufferSize(0),
			BufferIndex(0),
			Progress(0)
		{
			IF(!Tokeniser.parse_next(&Buffer[0]))
				RETURN;
			IF(Tokeniser.parse_next(&Buffer[1]))
				BufferSize := 2;
			ELSE
				BufferSize := 1;
		}

		fail(reason: CHAR#\) VOID
		{
			line: UINT;
			column: UINT;
			IF(BufferSize)
			{
				File->position(
					Buffer[BufferIndex].Content.Start,
					&line,
					&column);
			} ELSE
				Tokeniser.position(&line, &column);
			
			THROW ReasonError(
				File,
				line,
				column,
				Buffer,
				BufferIndex,
				BufferSize,
				THIS,
				reason);
		}

		consume(type: tok::Type) tok::Token - std::Opt
		{
			t: tok::Token;
			IF(match(type))
			{
				t := eat_token()!;
				= :a(&&t);
			}
			= NULL;
		}

		expect(type: tok::Type) tok::Token
		{
			IF(tok ::= consume(type))
				= &&*tok;

			line: UINT;
			column: UINT;
			IF(BufferSize)
				File->position(
					Buffer[BufferIndex].Content.Start,
					&line,
					&column);
			ELSE
				Tokeniser.position(&line, &column);

			THROW <ExpectedToken>(
				File, line, column,
				Buffer, BufferIndex, BufferSize,
				THIS,
				type);
		}

		match_seq(tok1: tok::Type, tok2: tok::Type) BOOL
		{
			IF(BufferSize < 2) = FALSE;
			= Buffer[BufferIndex].Type == tok1
				&& Buffer[BufferIndex^1].Type == tok2;
		}

		match(type: tok::Type) BOOL
		{
			IF(!BufferSize)
				RETURN FALSE;

			RETURN Buffer[BufferIndex].Type == type;
		}

		match_ahead(type: tok::Type) BOOL
		{
			IF(BufferSize != 2)
				RETURN FALSE;

			RETURN Buffer[BufferIndex^1].Type == type;
		}

		eat_token() tok::Token - std::Opt
		{
			IF(!BufferSize)
				RETURN NULL;

			out ::= Buffer[BufferIndex];

			IF(!Tokeniser.parse_next(&Buffer[BufferIndex]))
				--BufferSize;

			BufferIndex := BufferIndex ^ 1;
			++Progress;

			= :a(&&out);
		}

		# eof() BOOL := BufferSize == 0;

		# context() CHAR #\
			:= Ctx
				? Ctx->Name
				: "<unknown context>";

		# progress() UINT := Progress;

		# position() UM := BufferSize
			? Buffer[BufferIndex].Content.Start
			: ##File->Contents;

		Ctx: Trace *;
	PRIVATE:
		File: src::File #\;
		Tokeniser: tok::Tokeniser;
		Buffer: tok::Token[2]; // Lookahead buffer.
		BufferIndex: UINT;
		BufferSize: UINT;
		Progress: UINT;
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