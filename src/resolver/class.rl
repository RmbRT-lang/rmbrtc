INCLUDE "../scoper/class.rl"
INCLUDE "member.rl"
INCLUDE "type.rl"
INCLUDE "symbol.rl"

::rlc::resolver Class VIRTUAL -> ScopeItem
{
	# FINAL type() ScopeItem::Type := :class;

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
	Fields: MemberVariable - std::Vector;
	Constructors: Constructor - std::Vector;
	Destructor: resolver::Destructor - std::Dynamic;
	Functions: MemberFunction - std::Dynamic - std::Vector;
	Types: Member - std::Dynamic - std::Vector;

	{
		class: scoper::Class #\
	}:	ScopeItem(class),
		IsVirtual(class->Virtual)
	{
		scope ::= class->parent_scope();
		FOR(group ::= class->Items.start(); group; ++group)
			FOR(item ::= (*group)->Items.start(); item; ++item)
			{
				member # ::= <<scoper::Member#\>>(&**item);
				ASSERT(member);
				SWITCH(type ::= (*item)->type())
				{
				CASE :variable:
					Fields += <<scoper::MemberVariable#\>>(member);
				CASE :function:
					Functions += :gc(std::[MemberFunction]new(<scoper::MemberFunction#\>(member)));
				CASE :constructor:
					Constructors += <scoper::Constructor#\>(member);
				CASE :destructor:
					Destructor := :gc(std::[resolver::Destructor]new(
						<scoper::Destructor#\>(member)));
				CASE :enum, :typedef, :class, :rawtype, :union:
					Types += :gc(Member::create(member));
				DEFAULT:
					THROW <std::err::Unimplemented>(type.NAME());
				}
			}

		FOR(it ::= class->Inheritances.start(); it; ++it)
			Inheritances += (scope, *it);
	}
}

::rlc::resolver GlobalClass -> Global, Class
{

	{
		class: scoper::GlobalClass #\
	}:	Class(class);
}

::rlc::resolver MemberClass -> Member, Class
{
	{
		class: scoper::MemberClass #\
	}:	Class(class),
		Member(class);
}