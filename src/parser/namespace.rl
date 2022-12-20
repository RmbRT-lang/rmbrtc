INCLUDE "../ast/namespace.rl"
INCLUDE "../ast/test.rl"
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
	out.Parent := NULL; /// Sanitise parent.

	IF(p.consume(:braceOpen))
	{
		WHILE(entry ::= global::parse(p))
			TYPE SWITCH(entry!)
			{
			ast::[Config]Test:
				out.Tests += <ast::[Config]Test&&>(&&entry!);
			DEFAULT:
				out.Entries += :!(&&entry);
			}

		p.expect(:braceClose);

		= TRUE;
	}

	IF(entry ::= global::parse(p))
	{
		TYPE SWITCH(entry!)
		{
		ast::[Config]Test:
			out.Tests += <ast::[Config]Test&&>(&&entry!);
		DEFAULT:
			out.Entries += :!(&&entry);
		}
		= TRUE;
	}

	p.fail("expected scope entry");
	= FALSE;
}