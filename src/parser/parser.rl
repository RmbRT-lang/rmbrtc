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

		fail() VOID { error(); }

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