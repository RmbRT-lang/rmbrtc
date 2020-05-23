INCLUDE "scopeitem.rl"
INCLUDE "global.rl"
INCLUDE "parser.rl"

INCLUDE 'std/vector'

::rlc::parser Namespace -> VIRTUAL ScopeItem, Global
{
	Entries: std::[std::[Global]Dynamic]Vector;
	Name: src::String;

	# FINAL name() src::String#& := Name;
	# FINAL type() Global::Type := Global::Type::namespace;

	parse(
		p: Parser &) bool
	{
		IF(!p.consume(tok::Type::doubleColon))
			RETURN FALSE;

		t: Trace(&p, "namespace");
		name: tok::Token;
		p.expect(tok::Type::identifier, &name);
		Name := name.Content;

		IF(p.consume(tok::Type::braceOpen))
		{
			WHILE(entry ::= Global::parse(p))
				Entries.push_back(entry);

			p.expect(tok::Type::braceClose);

			RETURN TRUE;
		}

		IF(entry ::= Global::parse(p))
		{
			Entries.push_back(entry);
			RETURN TRUE;
		}

		p.fail("expected scope entry");
		RETURN FALSE;
	}
}