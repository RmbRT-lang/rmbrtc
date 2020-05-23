INCLUDE "type.rl"
INCLUDE "scopeitem.rl"
INCLUDE "global.rl"
INCLUDE "member.rl"

::rlc::parser Typedef -> VIRTUAL ScopeItem
{
	Type: std::[parser::Type]Dynamic;
	Name: src::String;

	# FINAL name() src::String#& := Name;

	parse(p: Parser&) bool
	{
		IF(!p.consume(tok::Type::type))
			RETURN FALSE;
		t: Trace(&p, "typedef");

		name: tok::Token;
		p.expect(tok::Type::identifier, &name);
		Name := name.Content;
		p.expect(tok::Type::colonEqual);

		printf("typedef: type\n");
		Type ::= parser::Type::parse(p);
		IF(!Type)
			p.fail("expected type");

		p.expect(tok::Type::semicolon);

		RETURN TRUE;
	}
}

::rlc::parser GlobalTypedef -> Global, Typedef
{
	# FINAL type() Global::Type := Global::Type::typedef;
	parse(p: Parser&) INLINE ::= Typedef::parse(p);
}

::rlc::parser MemberTypedef -> Member, Typedef
{
	# FINAL type() Member::Type := Member::Type::typedef;
	parse(p: Parser&) INLINE ::= Typedef::parse(p);
}