INCLUDE "scopeitem.rl"
INCLUDE "parser.rl"
INCLUDE "../src/file.rl"

INCLUDE 'std/vector'

::rlc::parser Enum VIRTUAL -> ScopeItem
{
	Constant -> ScopeItem, Member
	{
		Name: src::String;
		Value: src::Index;

		# FINAL name() src::String#& := Name;
		# FINAL overloadable() BOOL := FALSE;
	}

	Name: src::String;
	Constants: std::[Constant]Vector;

	# FINAL name() src::String#& := Name;
	# FINAL overloadable() BOOL := FALSE;

	parse(p: Parser &) BOOL
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
	parse(p: Parser&) BOOL := Enum::parse(p);
}

::rlc::parser MemberEnum -> Member, Enum
{
	parse(p: Parser&) BOOL := Enum::parse(p);
}