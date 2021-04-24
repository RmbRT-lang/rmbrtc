INCLUDE "scopeitem.rl"
INCLUDE "parser.rl"
INCLUDE "../src/file.rl"

INCLUDE 'std/vector'
INCLUDE 'std/memory'


::rlc::parser Class -> VIRTUAL ScopeItem
{
	Inheritance
	{
		Visibility: rlc::Visibility;
		IsVirtual: bool;
		Type: Symbol;

		parse(p: Parser &) VOID
		{
			STATIC lookup: {tok::Type, rlc::Visibility}#[](
				(:public, :public),
				(:private, :private),
				(:protected, :protected));

			t: Trace(&p, "inheritance");

			Visibility := :public;
			FOR(i ::= 0; i < ::size(lookup); i++)
				IF(p.consume(lookup[i].(0)))
				{
					Visibility := lookup[i].(1);
					BREAK;
				}

			IsVirtual := p.consume(:virtual);

			IF(!Type.parse(p))
				p.fail("expected type");
		}
	}

	Name: src::String;
	Virtual: bool;
	Members: std::[std::[Member]Dynamic]Vector;
	Inheritances: std::[Inheritance]Vector;

	# FINAL name() src::String #& := Name;
	# FINAL overloadable() bool := FALSE;

	parse(p: Parser &) bool
	{
		IF(!p.match(:identifier)
		|| (!p.match_ahead(:braceOpen)
			&& !p.match_ahead(:minusGreater)
			&& !p.match_ahead(:virtual)))
			RETURN FALSE;

		t: Trace(&p, "class");

		p.expect(:identifier, &Name);

		Virtual := p.consume(:virtual);

		IF(p.consume(:minusGreater))
			DO(i: Inheritance)
			{
				i.parse(p);
				Inheritances += &&i;
			} WHILE(p.consume(:comma))

		p.expect(:braceOpen);

		default ::= Visibility::public;
		WHILE(member ::= Member::parse(p, default))
			Members += :gc(member);

		p.expect(:braceClose);

		RETURN TRUE;
	}
}

::rlc::parser GlobalClass -> Global, Class
{
	# FINAL type() Global::Type := :class;
	parse(p: Parser &) INLINE bool := Class::parse(p);
}
::rlc::parser MemberClass -> Member, Class
{
	# FINAL type() Member::Type := :class;
	parse(p: Parser &) INLINE bool := Class::parse(p);
}