INCLUDE "type.rl"
INCLUDE "scopeentry.rl"

::rlc::parser Typedef -> ScopeEntry
{
	Type: std::[parser::Type]Dynamic;

	# FINAL type() ScopeEntryType := ScopeEntryType::typedef;

	parse(p: Parser&) bool
	{
		IF(!p.consume(tok::Type::type))
			RETURN FALSE;

		name: tok::Token;
		p.expect(tok::Type::identifier, &name);
		Name := name.Content;
		p.expect(tok::Type::colonEqual);

		printf("typedef: type\n");
		Type ::= parser::Type::parse(p);
		printf("typedef: after type\n");
		IF(!Type)
			p.fail();

		p.expect(tok::Type::semicolon);

		RETURN TRUE;
	}
}