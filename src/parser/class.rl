INCLUDE "scopeitem.rl"
INCLUDE "parser.rl"
INCLUDE "../src/file.rl"

INCLUDE 'std/vector'
INCLUDE 'std/memory'
INCLUDE 'std/pair'

::rlc::parser Class -> VIRTUAL ScopeItem
{
	Inheritance
	{
		Visibility: rlc::Visibility;
		IsVirtual: bool;
		Type: Symbol;

		parse(p: Parser &) VOID
		{
			STATIC lookup: std::[tok::Type, rlc::Visibility]Pair#[](
				std::pair(tok::Type::public, Visibility::public),
				std::pair(tok::Type::private, Visibility::private),
				std::pair(tok::Type::protected, Visibility::protected));

			t: Trace(&p, "inheritance");

			Visibility := Visibility::public;
			FOR(i ::= 0; i < ::size(lookup); i++)
				IF(p.consume(lookup[i].First))
				{
					Visibility := lookup[i].Second;
					BREAK;
				}

			IsVirtual := p.consume(tok::Type::virtual);

			IF(!Type.parse(p))
				p.fail("expected type");
		}
	}

	Name: src::String;
	Members: std::[std::[Member]Dynamic]Vector;
	Inheritances: std::[Inheritance]Vector;

	# FINAL name() src::String #& := Name;

	parse(p: Parser &) bool
	{
		IF(!p.match(tok::Type::identifier)
		|| !p.match_ahead(tok::Type::braceOpen)
		&& !p.match_ahead(tok::Type::minusGreater))
			RETURN FALSE;

		p.expect(tok::Type::identifier, &Name);

		IF(p.consume(tok::Type::minusGreater))
			DO(i: Inheritance)
			{
				i.parse(p);
				Inheritances.push_back(__cpp_std::move(i));
			} WHILE(p.consume(tok::Type::comma))

		p.expect(tok::Type::braceOpen);

		default ::= Visibility::public;
		WHILE(member ::= Member::parse(p, default))
			Members.push_back(member);

		p.expect(tok::Type::braceClose);

		RETURN TRUE;
	}
}

::rlc::parser GlobalClass -> Global, Class
{
	# FINAL type() Global::Type := Global::Type::class;
	parse(p: Parser &) INLINE bool := Class::parse(p);
}
::rlc::parser MemberClass -> Member, Class
{
	# FINAL type() Member::Type := Member::Type::class;
	parse(p: Parser &) INLINE bool := Class::parse(p);
}