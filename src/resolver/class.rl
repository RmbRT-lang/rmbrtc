INCLUDE "../scoper/class.rl"
INCLUDE "member.rl"
INCLUDE "type.rl"
INCLUDE "symbol.rl"

::rlc::resolver Class VIRTUAL -> ScopeItem
{
	Inheritance
	{
		Visibility: rlc::Visibility;
		IsVirtual: BOOL;
		Type: Symbol;

		{scope: scoper::Scope #\, inheritance: scoper::Class::Inheritance #&}:
			Visibility(inheritance.Visibility),
			IsVirtual(inheritance.IsVirtual),
			Type(:resolve(*scope, inheritance.Type));
	}

	IsVirtual: BOOL;
	Inheritances: Inheritance - std::Vector;
	Fields: MemberVariable - std::DynVector;
	Constructors: Constructor - std::DynVector;
	Destructor: resolver::Destructor - std::Dynamic;
	Functions: MemberFunction - std::DynVector;
	Types: Member - std::DynVector;

	{
		class: scoper::Class #\,
		cache: Cache &
	}->	ScopeItem(class, cache)
	:	IsVirtual(class->Virtual)
	{
		scope ::= class->parent_scope();
		FOR(group ::= class->Items.start(); group; ++group)
			FOR(item ::= group!->Items.start(); item; ++item)
			{
				member # ::= <<scoper::Member#\>>(item!);
				TYPE SWITCH(member)
				{
				CASE scoper::MemberVariable:
					Fields += :create(<scoper::MemberVariable#\>(member), cache);
				CASE scoper::MemberFunction:
					Functions += :create(<scoper::MemberFunction#\>(member), cache);
				CASE scoper::Constructor:
					Constructors += :create(<scoper::Constructor#\>(member), cache);
				CASE scoper::Destructor:
					Destructor := :create(<scoper::Destructor#\>(member), cache);
				CASE scoper::MemberEnum,
					scoper::MemberTypedef,
					scoper::MemberClass,
					scoper::MemberRawtype,
					scoper::MemberUnion:
					Types += :gc(<<<Member>>>(member, cache));
				DEFAULT:
					THROW <std::err::Unimplemented>(TYPE(member));
				}
			}

		FOR(it ::= class->Inheritances.start(); it; ++it)
			Inheritances += (scope, it!);
	}
}

::rlc::resolver GlobalClass -> Global, Class
{
	{
		class: scoper::GlobalClass #\,
		cache: Cache &
	}->	Class(class, cache);
}

::rlc::resolver MemberClass -> Member, Class
{
	{
		class: scoper::MemberClass #\,
		cache: Cache &
	}->	Class(class, cache),
		Member(class);
}