INCLUDE "parser.rl"
INCLUDE "global.rl"
INCLUDE "member.rl"
INCLUDE "function.rl"
INCLUDE "templatedecl.rl"
INCLUDE "scopeitem.rl"
INCLUDE "global.rl"
INCLUDE "member.rl"

INCLUDE 'std/vector'
INCLUDE 'std/memory'

::rlc::parser Concept -> VIRTUAL ScopeItem
{
	Members: std::[std::[Member]Dynamic]Vector;
	Name: src::String;

	# FINAL name() src::String#& := Name;
	# FINAL overloadable() bool := FALSE;

	parse(p: Parser&) bool
	{
		IF(!p.consume(:concept))
			RETURN FALSE;

		t: Trace(&p, "concept");

		p.expect(:identifier, &Name);
		p.expect(:braceOpen);

		DO(default_visibility: Visibility := Visibility::public)
			IF(member ::= detail::parse_concept_member(p, default_visibility))
				Members += :gc(member);
			ELSE
				p.fail("expected member");
			WHILE(!p.consume(:braceClose))

		RETURN TRUE;
	}
}

::rlc::parser GlobalConcept -> Global, Concept
{
	# FINAL type() Global::Type := :concept;

	parse(p: Parser&) bool := Concept::parse(p);
}