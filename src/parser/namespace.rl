INCLUDE "../ast/namespace.rl"
INCLUDE "parser.rl"


::rlc::parser::namespace parse(
	p: Parser &,
	out: ast::[Config]Namespace &) BOOL
{
	IF(!p.consume(:doubleColon))
		= FALSE;

	t: Trace(&p, "namespace");
	name ::= p.expect(:identifier);
	out.Name := name.Content;
	out.Position := name.Position;

	IF(p.consume(:braceOpen))
	{
		WHILE(entry ::= global::parse(p))
			out.Entries += :!(&&entry);

		p.expect(:braceClose);

		= TRUE;
	}

	IF(entry ::= global::parse(p))
	{
		out.Entries += :!(&&entry);
		= TRUE;
	}

	p.fail("expected scope entry");
	= FALSE;
}