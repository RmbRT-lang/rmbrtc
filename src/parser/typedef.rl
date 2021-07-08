INCLUDE "type.rl"
INCLUDE "scopeitem.rl"
INCLUDE "global.rl"
INCLUDE "member.rl"

::rlc::parser Typedef VIRTUAL -> ScopeItem
{
	Type: std::[parser::Type]Dynamic;
	Name: src::String;

	# FINAL type() ScopeItem::Type := :typedef;
	# FINAL name() src::String#& := Name;
	# FINAL overloadable() BOOL := FALSE;

	parse(p: Parser&) BOOL
	{
		IF(!p.consume(:type))
			RETURN FALSE;
		t: Trace(&p, "typedef");

		name: tok::Token;
		p.expect(:identifier, &name);
		Name := name.Content;
		p.expect(:colonEqual);

		Type := :gc(parser::Type::parse(p));
		IF(!Type)
			p.fail("expected type");

		p.expect(:semicolon);

		RETURN TRUE;
	}
}

::rlc::parser GlobalTypedef -> Global, Typedef
{
	parse(p: Parser&) INLINE ::= Typedef::parse(p);
}

::rlc::parser MemberTypedef -> Member, Typedef
{
	parse(p: Parser&) INLINE ::= Typedef::parse(p);
}