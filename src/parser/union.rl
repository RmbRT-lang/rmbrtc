INCLUDE "scopeitem.rl"
INCLUDE "global.rl"
INCLUDE "member.rl"

::rlc::parser Union VIRTUAL -> ScopeItem
{
	Name: src::String;
	Members: std::[std::[Member]Dynamic]Vector;

	# FINAL type() ScopeItem::Type := :union;
	# FINAL name() src::String #& := Name;
	# FINAL overloadable() BOOL := FALSE;

	parse(p: Parser &) BOOL
	{
		IF(!p.consume(:union))
			RETURN FALSE;

		p.expect(:identifier, &Name);

		p.expect(:braceOpen);

		visibility ::= Visibility::public;
		WHILE(member ::= Member::parse(p, visibility))
			Members += :gc(member);

		p.expect(:braceClose);

		RETURN TRUE;
	}
}

::rlc::parser GlobalUnion -> Global, Union
{
	parse(p: Parser &) INLINE BOOL := Union::parse(p);
}

::rlc::parser MemberUnion -> Member, Union
{
	parse(p: Parser &) INLINE BOOL := Union::parse(p);
}