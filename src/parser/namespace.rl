INCLUDE "scopeitem.rl"
INCLUDE "global.rl"
INCLUDE "parser.rl"

INCLUDE 'std/vector'

::rlc::parser Namespace -> VIRTUAL ScopeItem, Global
{
	Entries: std::[std::[Global]Dynamic]Vector;
	Name: src::String;

	# FINAL name() src::String#& := Name;
	# FINAL type() Global::Type := :namespace;
	# FINAL overloadable() BOOL := TRUE;

	parse(
		p: Parser &) BOOL
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
				Entries += :gc(entry);

			p.expect(:braceClose);

			RETURN TRUE;
		}

		IF(entry ::= Global::parse(p))
		{
			Entries += :gc(entry);
			RETURN TRUE;
		}

		p.fail("expected scope entry");
		RETURN FALSE;
	}
}