INCLUDE "type.rl"
INCLUDE "scopeitem.rl"
INCLUDE "global.rl"
INCLUDE "member.rl"

::rlc::parser Typedef -> VIRTUAL ScopeItem
{
	Type: std::[parser::Type]Dynamic;
	Name: src::String;

	# FINAL name() src::String#& := Name;
	# FINAL overloadable() bool := FALSE;

	parse(p: Parser&) bool
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
	# FINAL type() Global::Type := :typedef;
	parse(p: Parser&) INLINE ::= Typedef::parse(p);
}

::rlc::parser MemberTypedef -> Member, Typedef
{
	# FINAL type() Member::Type := :typedef;
	parse(p: Parser&) INLINE ::= Typedef::parse(p);
}