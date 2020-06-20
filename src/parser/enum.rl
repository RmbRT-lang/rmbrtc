INCLUDE "scopeitem.rl"
INCLUDE "parser.rl"
INCLUDE "../src/file.rl"

INCLUDE 'std/vector'
INCLUDE 'std/memory'
INCLUDE 'std/pair'

::rlc::parser Enum -> VIRTUAL ScopeItem
{
	Constant -> VIRTUAL ScopeItem, Member
	{
		Name: src::String;
		Value: src::Index;

		# FINAL name() src::String#& := Name;
		# FINAL type() Member::Type := Member::Type::enumConstant;
	}

	Name: src::String;
	Constants: std::[Constant]Vector;

	# FINAL name() src::String#& := Name;

	parse(p: Parser &) bool
	{
		IF(!p.consume(tok::Type::enum))
			RETURN FALSE;

		t: Trace(&p, "enum");

		p.expect(tok::Type::identifier, &Name);
		p.expect(tok::Type::braceOpen);

		DO(c: Constant)
			DO()
			{
				p.expect(tok::Type::identifier, &c.Name);
				Constants.push_back(__cpp_std::move(c));
			} WHILE(p.consume(tok::Type::colonEqual))
		FOR(p.consume(tok::Type::comma); c.Value++)

		p.expect(tok::Type::braceClose);
		RETURN TRUE;
	}
}

::rlc::parser GlobalEnum -> Global, Enum
{
	# FINAL type() Global::Type := Global::Type::enum;
	parse(p: Parser&) bool := Enum::parse(p);
}

::rlc::parser MemberEnum -> Member, Enum
{
	# FINAL type() Member::Type := Member::Type::enum;
	parse(p: Parser&) bool := Enum::parse(p);
}