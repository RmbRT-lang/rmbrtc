INCLUDE "statement.rl"

::rlc::parser Destructor -> Member
{
	# FINAL type() Member::Type := :destructor;
	# FINAL name() src::String#& := Name;

	Name: src::String; // Always DESTRUCTOR.
	Body: BlockStatement;
	Inline: bool;

	parse(p: Parser&) bool
	{
		IF(!p.consume(:destructor, &Name))
			RETURN FALSE;

		Inline := p.consume(:inline);

		IF(!Body.parse(p))
			p.fail("expected body");

		RETURN TRUE;
	}
}