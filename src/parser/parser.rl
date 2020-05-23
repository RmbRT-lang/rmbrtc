INCLUDE "../tokeniser/tokeniser.rl"
INCLUDE "error.rl"

::rlc::parser
{
	Parser -> tok::Tokeniser
	{
		CONSTRUCTOR(
			file: src::File #\):
			Tokeniser(file),
			Ctx(NULL);

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
				position(&line, &column);
			
			THROW Error(
				File,
				line,
				column,
				Buffer,
				BufferIndex,
				BufferSize,
				*THIS,
				reason);
		}

		# context() char #\
			:= Ctx
				? Ctx->Name
				: "<unknown context>";

		Ctx: Trace *;
	}

	Trace
	{
		CONSTRUCTOR(
			p: Parser \,
			name: char#\):
			P(p),
			Name(name),
			Prev(p->Ctx)
		{
			P->Ctx := THIS;
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