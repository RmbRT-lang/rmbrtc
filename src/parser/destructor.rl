INCLUDE "statement.rl"

::rlc::parser Destructor -> Member
{
	# FINAL type() Member::Type := Member::Type::destructor;
	# FINAL name() src::String#& := Name;

	Name: src::String; // Always DESTRUCTOR.
	Body: BlockStatement;
	Inline: bool;

	parse(p: Parser&) bool
	{
		IF(!p.consume(tok::Type::destructor))
			RETURN FALSE;

		Inline := p.consume(tok::Type::inline);

		IF(!Body.parse(p))
			p.fail("expected body");

		RETURN TRUE;
	}
}