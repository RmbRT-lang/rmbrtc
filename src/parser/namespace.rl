INCLUDE "scopeentry.rl"
INCLUDE "parser.rl"

INCLUDE 'std/vector'

::rlc::parser Namespace -> ScopeEntry
{
	Entries: std::[std::[ScopeEntry]Dynamic]Vector;

	# FINAL type() ScopeEntryType := ScopeEntryType::namespace;

	parse(
		p: Parser &) bool
	{
		IF(!p.consume(tok::Type::doubleColon))
			RETURN FALSE;

		name: tok::Token;
		p.expect(tok::Type::identifier, &name);
		Name := name.Content;

		IF(p.consume(tok::Type::braceOpen))
		{
			WHILE(entry ::= ScopeEntry::parse(p))
				Entries.push_back(entry);

			p.expect(tok::Type::braceClose);

			RETURN TRUE;
		}

		IF(entry ::= ScopeEntry::parse(p))
		{
			Entries.push_back(entry);
			RETURN TRUE;
		}

		p.fail();
		RETURN FALSE;
	}
}