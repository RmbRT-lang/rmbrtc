

::rlc::parser::namespace parse(
	p: Parser &,
	out: ast::[Config]Namespace) BOOL
{
	IF(!p.consume(:doubleColon))
		RETURN FALSE;

	t: Trace(&p, "namespace");
	name: tok::Token;
	p.expect(:identifier, &name);
	Name := name.Content;

	IF(p.consume(:braceOpen))
	{
		WHILE(entry ::= Global::parse(p))
			Entries += :gc(<<ScopeItem \>>(entry));

		p.expect(:braceClose);

		RETURN TRUE;
	}

	IF(entry ::= Global::parse(p))
	{
		Entries += :gc(<<ScopeItem \>>(entry));
		RETURN TRUE;
	}

	p.fail("expected scope entry");
	RETURN FALSE;
}