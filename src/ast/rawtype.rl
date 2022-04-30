INCLUDE "scopeitem.rl"
INCLUDE "global.rl"
INCLUDE "member.rl"
INCLUDE "expression.rl"
INCLUDE "../src/file.rl"

INCLUDE 'std/memory'
INCLUDE 'std/vector'

::rlc::parser Rawtype VIRTUAL -> ScopeItem
{
	Size: Expression-std::Dyn;
	Members: Member - std::DynVec;
	Name: src::String;

	# FINAL name() src::String #& := Name;
	# FINAL overloadable() BOOL := FALSE;

	parse(p: Parser &) BOOL
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
	parse(p: Parser &) INLINE BOOL := Rawtype::parse(p);
}

::rlc::parser MemberRawtype -> Member, Rawtype
{
	parse(p: Parser &) INLINE BOOL := Rawtype::parse(p);
}