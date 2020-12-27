INCLUDE "scopeitem.rl"
INCLUDE "parser.rl"
INCLUDE "../src/file.rl"

INCLUDE 'std/vector'

::rlc::parser Enum -> VIRTUAL ScopeItem
{
	Constant -> VIRTUAL ScopeItem, Member
	{
		Name: src::String;
		Value: src::Index;

		# FINAL name() src::String#& := Name;
		# FINAL type() Member::Type := :enumConstant;
	}

	Name: src::String;
	Constants: std::[Constant]Vector;

	# FINAL name() src::String#& := Name;

	parse(p: Parser &) bool
	{
		IF(!p.consume(:enum))
			RETURN FALSE;

		t: Trace(&p, "enum");

		p.expect(:identifier, &Name);
		p.expect(:braceOpen);

		DO(c: Constant)
			DO()
			{
				p.expect(:identifier, &c.Name);
				Constants += &&c;
			} WHILE(p.consume(:colonEqual))
		FOR(p.consume(:comma); c.Value++)

		p.expect(:braceClose);
		RETURN TRUE;
	}
}

::rlc::parser GlobalEnum -> Global, Enum
{
	# FINAL type() Global::Type := :enum;
	parse(p: Parser&) bool := Enum::parse(p);
}

::rlc::parser MemberEnum -> Member, Enum
{
	# FINAL type() Member::Type := :enum;
	parse(p: Parser&) bool := Enum::parse(p);
}