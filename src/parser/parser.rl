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
			file: src::File #\,
			fileIndex: U1
		}:
			File(file),
			Tokeniser(file, fileIndex),
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

		consume(type: tok::Type) BOOL
			:= consume(type, <tok::Token*>(NULL));

		consume(type: tok::Type, pos: src::Position \) BOOL
		{
			token: tok::Token;
			IF(consume(type, &token))
			{
				*pos := token.Position;
				RETURN TRUE;
			}
			RETURN FALSE;
		}

		consume(
			type: tok::Type,
			out: tok::Token *) BOOL
		{
			IF(match(type))
			{
				consume(out);
				RETURN TRUE;
			}

			RETURN FALSE;
		}

		consume(type: tok::Type, out: src::String \) BOOL
		{
			token: tok::Token;
			IF(consume(type, &token))
			{
				*out := token.Content;
				RETURN TRUE;
			}
			RETURN FALSE;
		}

		consume(type: tok::Type, out: src::String \, pos: src::Position \) BOOL
		{
			token: tok::Token;
			IF(consume(type, &token))
			{
				*out := token.Content;
				*pos := token.Position;
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
				line: UINT;
				column: UINT;
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
			token: tok::Token;
			expect(type, &token);
			*out := token.Content;
		}

		expect(type: tok::Type, out: src::String \, pos: src::Position \) VOID
		{
			token: tok::Token;
			expect(type, &token);
			*out := token.Content;
			*pos := token.Position;
		}

		match(type: tok::Type) BOOL
		{
			IF(!BufferSize)
				RETURN FALSE;

			RETURN Buffer[BufferIndex].Type == type;
		}

		match(type: tok::Type, out: src::String \) BOOL
		{
			ret: BOOL;
			IF(ret := match(type))
				*out := Buffer[BufferIndex].Content;
			RETURN ret;
		}

		match_ahead(type: tok::Type) BOOL
		{
			IF(BufferSize != 2)
				RETURN FALSE;

			RETURN Buffer[BufferIndex^1].Type == type;
		}

		consume(out: tok::Token *) BOOL
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