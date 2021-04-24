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
			file: src::File #\}:
			File(file),
			Tokeniser(file),
			Ctx(NULL),
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

		fail(reason: char#\) VOID
		{
			line: uint;
			column: uint;
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


		consume(type: tok::Type) bool
			:= consume(type, <tok::Token*>(NULL));

		consume(
			type: tok::Type,
			out: tok::Token *) bool
		{
			IF(match(type))
			{
				consume(out);
				RETURN TRUE;
			}

			RETURN FALSE;
		}

		consume(type: tok::Type, out: src::String \) bool
		{
			token: tok::Token;
			IF(consume(type, &token))
			{
				*out := token.Content;
				RETURN TRUE;
			}
			RETURN FALSE;
		}

		expect(type: tok::Type) VOID
			:= expect(type, <tok::Token *>(NULL));

		expect(type: tok::Type, out: tok::Token *) VOID
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
				}
				ELSE
				{
					Tokeniser.position(&line, &column);
				}
				THROW ExpectedToken(File, line, column, Buffer, BufferIndex, BufferSize, THIS, type);
			}
		}

		expect(type: tok::Type, out: src::String \) VOID
		{
			tok: tok::Token;
			expect(type, &tok);
			*out := tok.Content;
		}

		match(type: tok::Type) bool
		{
			IF(!BufferSize)
				RETURN FALSE;

			RETURN Buffer[BufferIndex].Type == type;
		}

		match_ahead(type: tok::Type) bool
		{
			IF(BufferSize != 2)
				RETURN FALSE;

			RETURN Buffer[BufferIndex^1].Type == type;
		}

		consume(out: tok::Token *) bool
		{
			IF(!BufferSize)
				RETURN FALSE;

			IF(out)
				*out := Buffer[BufferIndex];

			IF(!Tokeniser.parse_next(&Buffer[BufferIndex]))
				--BufferSize;

			BufferIndex := BufferIndex ^ 1;
			++Progress;

			RETURN TRUE;
		}

		# context() char #\
			:= Ctx
				? Ctx->Name
				: "<unknown context>";

		# progress() ushort := Progress;

		# position() UM := BufferSize
			? Buffer[BufferIndex].Content.Start
			: File->Contents.size();

		Ctx: Trace *;
	PRIVATE:
		File: src::File #\;
		Tokeniser: tok::Tokeniser;
		Buffer: tok::Token[2]; // Lookahead buffer.
		BufferIndex: ushort;
		BufferSize: ushort;
		Progress: ushort;
	}

	Trace
	{
		{
			p: Parser \,
			name: char#\}:
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
		Name: char #\;
		Prev: Trace *;
	}
}