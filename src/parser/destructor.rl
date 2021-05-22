INCLUDE "statement.rl"

::rlc::parser Destructor -> Member
{
	# FINAL type() Member::Type := :destructor;
	# FINAL name() src::String#& := Name;
	# FINAL overloadable() BOOL := FALSE;

	Name: src::String; // Always DESTRUCTOR.
	Body: BlockStatement;
	Inline: BOOL;

	parse(p: Parser&) BOOL
	{
		IF(!p.consume(:destructor, &Name))
			RETURN FALSE;

		Inline := p.consume(:inline);

		IF(!Body.parse(p))
			p.fail("expected body");

		RETURN TRUE;
	}
}