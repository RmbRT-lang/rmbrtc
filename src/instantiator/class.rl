INCLUDE "../resolver/class.rl"
INCLUDE "member.rl"
INCLUDE "type.rl"
INCLUDE "symbol.rl"

::rlc::instantiator Class VIRTUAL -> Instance
{
	Inheritance
	{
		Visibility: rlc::Visibility;
		IsVirtual: BOOL;
		Type: Instance \;

		{scope: scoper::Scope #\, inheritance: scoper::Class::Inheritance #&}:
			Visibility(inheritance.Visibility),
			IsVirtual(inheritance.IsVirtual),
			Type(:resolve(*scope, inheritance.Type));
	}

	IsVirtual: BOOL;
	Inheritances: Inheritance - std::Vector;
	Fields: MemberVariable - std::DynVector;
	Constructors: Constructor - std::DynVector;
	Destructor: instantiator::Destructor - std::Dynamic;
	Functions: std::[Class; MemberFunction]NatDynMap;
	Operators: std::[rlc::Operator; Operator\]NatMap;
	Types: Member #\ - std::Vector;

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
				scoper::MemberVariable:
					Fields += :create(<scoper::MemberVariable#\>(member), cache);
				scoper::MemberFunction:
					Functions += :create(<scoper::MemberFunction#\>(member), cache);
				scoper::Constructor:
					Constructors += :create(<scoper::Constructor#\>(member), cache);
				scoper::Destructor:
					Destructor := :create(<scoper::Destructor#\>(member), cache);
				scoper::MemberEnum,
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