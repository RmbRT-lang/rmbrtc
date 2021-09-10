INCLUDE "scopeitem.rl"
INCLUDE "global.rl"
INCLUDE "parser.rl"

INCLUDE 'std/vector'

::rlc::parser Namespace -> ScopeItem, Global
{
	Entries: ScopeItem - std::DynVector;
	Name: src::String;

	# FINAL name() src::String#& := Name;
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
}