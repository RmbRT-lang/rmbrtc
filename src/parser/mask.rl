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

::rlc::parser Mask VIRTUAL -> ScopeItem
{
	Members: Member - std::DynVector;
	Name: src::String;

	# FINAL name() src::String#& := Name;
	# FINAL overloadable() BOOL := FALSE;

	parse(p: Parser&) BOOL
	{
		IF(!p.consume(:mask))
			RETURN FALSE;

		t: Trace(&p, "mask");

		p.expect(:identifier, &Name);
		p.expect(:braceOpen);

		DO(default_visibility: Visibility := Visibility::public)
			IF(member ::= detail::parse_mask_member(p, default_visibility))
				Members += :gc(member);
			ELSE
				p.fail("expected member");
			WHILE(!p.consume(:braceClose))

		RETURN TRUE;
	}
}

::rlc::parser GlobalMask -> Global, Mask
{
	parse(p: Parser&) BOOL := Mask::parse(p);
}