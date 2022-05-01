::rlc ENUM IncludeType
{
	// #include ""
	relative,
	// #include <>
	global,
	// Kind of like golang, low prio.
	remote
}

::rlc::parser Include
{
	Token: tok::Token;
	Type: IncludeType;

	{}: Type(NOINIT);

	parse(
		p: Parser &) BOOL
	{
		IF(!p.consume(:include))
			RETURN FALSE;

		_: Trace(&p, "include statement");

		IF(t ::= p.consume(:stringApostrophe))
			(Token, Type) := (t!, :global);
		ELSE IF(t ::= p.consume(:stringQuote))
			(Token, Type) := (t!, :relative);
		ELSE IF(t ::= p.consume(:stringBacktick))
			(Token, Type) := (t!, :remote);
		ELSE
			p.fail("expected ', \", or `");

		RETURN TRUE;
	}
}