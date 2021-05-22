INCLUDE "global.rl"
INCLUDE "scopeitem.rl"
INCLUDE "statement.rl"

::rlc::parser Test -> Global, VIRTUAL ScopeItem
{
	Name: tok::Token;
	Body: BlockStatement;

	# FINAL type() Global::Type := :test;
	# FINAL name() src::String#& := src::String::empty;
	# FINAL overloadable() BOOL := FALSE;

	parse(p: Parser &) BOOL
	{
		IF(!p.consume(:test))
			RETURN FALSE;

		t: Trace(&p, "test");

		p.expect(:stringQuote, &Name);

		IF(!Body.parse(p))
			p.fail("expected block statement");

		RETURN TRUE;
	}
}