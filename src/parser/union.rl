INCLUDE "scopeitem.rl"
INCLUDE "global.rl"
INCLUDE "member.rl"

::rlc::parser Union -> VIRTUAL ScopeItem
{
	Name: src::String;
	Members: std::[std::[Member]Dynamic]Vector;

	# FINAL name() src::String #& := Name;

	parse(p: Parser &) bool
	{
		IF(!p.consume(tok::Type::union))
			RETURN FALSE;

		p.expect(tok::Type::identifier, &Name);

		p.expect(tok::Type::braceOpen);

		visibility ::= Visibility::public;
		WHILE(member ::= Member::parse(p, visibility))
			Members.push_back(member);

		p.expect(tok::Type::braceClose);

		RETURN TRUE;
	}
}

::rlc::parser GlobalUnion -> Global, Union
{
	# FINAL type() Global::Type := Global::Type::union;

	parse(p: Parser &) INLINE bool := Union::parse(p);
}

::rlc::parser MemberUnion -> Member, Union
{
	# FINAL type() Member::Type := Member::Type::union;
	parse(p: Parser &) INLINE bool := Union::parse(p);
}