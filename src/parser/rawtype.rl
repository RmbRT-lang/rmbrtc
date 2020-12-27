INCLUDE "scopeitem.rl"
INCLUDE "global.rl"
INCLUDE "member.rl"
INCLUDE "expression.rl"
INCLUDE "../src/file.rl"

INCLUDE 'std/memory'
INCLUDE 'std/vector'

::rlc::parser Rawtype -> VIRTUAL ScopeItem
{
	Size: std::[Expression]Dynamic;
	Members: std::[std::[Member]Dynamic]Vector;
	Name: src::String;

	# FINAL name() src::String #& := Name;

	parse(p: Parser &) bool
	{
		IF(!p.consume(:parentheseOpen))
			RETURN FALSE;

		t: Trace(&p, "rawtype");

		IF(!(Size := :gc(Expression::parse(p))))
			p.fail("expected expression");

		p.expect(:parentheseClose);

		p.expect(:identifier, &Name);

		IF(p.consume(:semicolon))
			RETURN TRUE;

		p.expect(:braceOpen);

		visibility ::= Visibility::public;
		WHILE(member ::= Member::parse(p, visibility))
			Members += :gc(member);

		p.expect(:braceClose);

		RETURN TRUE;
	}
}

::rlc::parser GlobalRawtype -> Global, Rawtype
{
	# FINAL type() Global::Type := :rawtype;
	parse(p: Parser &) INLINE bool := Rawtype::parse(p);
}

::rlc::parser MemberRawtype -> Member, Rawtype
{
	# FINAL type() Member::Type := :rawtype;
	parse(p: Parser &) INLINE bool := Rawtype::parse(p);
}