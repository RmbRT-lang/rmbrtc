INCLUDE "global.rl"
INCLUDE "scopeitem.rl"
INCLUDE "statement.rl"

::rlc::parser Test -> Global, VIRTUAL ScopeItem
{
	Name: tok::Token;
	Body: BlockStatement;

	# FINAL type() Global::Type := Global::Type::test;
	# FINAL name() src::String#& := src::String::empty;

	parse(p: Parser &) bool
	{
		IF(!p.consume(tok::Type::test))
			RETURN FALSE;

		t: Trace(&p, "test");

		p.expect(tok::Type::stringQuote, &Name);

		IF(!Body.parse(p))
			p.fail("expected block statement");

		RETURN TRUE;
	}
}