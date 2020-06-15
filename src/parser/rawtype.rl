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
		IF(!p.consume(tok::Type::parentheseOpen))
			RETURN FALSE;

		t: Trace(&p, "rawtype");

		IF(!(Size := Expression::parse(p)).Ptr)
			p.fail("expected expression");

		p.expect(tok::Type::parentheseClose);

		p.expect(tok::Type::identifier, &Name);

		IF(p.consume(tok::Type::semicolon))
			RETURN TRUE;

		p.expect(tok::Type::braceOpen);

		visibility ::= Visibility::public;
		WHILE(member ::= Member::parse(p, visibility))
			Members.push_back(member);

		p.expect(tok::Type::braceClose);

		RETURN TRUE;
	}
}

::rlc::parser GlobalRawtype -> Global, Rawtype
{
	# FINAL type() Global::Type := Global::Type::rawtype;
	parse(p: Parser &) INLINE bool := Rawtype::parse(p);
}

::rlc::parser MemberRawtype -> Member, Rawtype
{
	# FINAL type() Member::Type := Member::Type::rawtype;
	parse(p: Parser &) INLINE bool := Rawtype::parse(p);
}