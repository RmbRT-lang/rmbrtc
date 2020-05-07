INCLUDE "parser.rl"

::rlc ENUM IncludeType
{
	// #include ""
	relative,
	// #include <>
	global,
	// Kind of like golang, low prio.
	remote
}

::rlc::parser
{
	Include
	{
		Token: tok::Token;
		Type: IncludeType;

		parse(
			p: Parser &) bool
		{
			IF(!p.consume(tok::Type::include))
				RETURN FALSE;

			t: Trace(&p, "include statement");

			IF(p.consume(tok::Type::stringApostrophe, &Token))
				Type := IncludeType::global;
			ELSE IF(p.consume(tok::Type::stringQuote, &Token))
				Type := IncludeType::relative;
			ELSE IF(p.consume(tok::Type::stringBacktick, &Token))
				Type := IncludeType::remote;
			ELSE
				p.fail();

			RETURN TRUE;
		}
	}
}