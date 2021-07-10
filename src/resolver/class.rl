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
	Fields: MemberVariable - std::Dynamic - std::Vector;
	Constructors: Constructor - std::Dynamic - std::Vector;
	Destructor: resolver::Destructor - std::Dynamic;
	Functions: MemberFunction - std::Dynamic - std::Vector;
	Types: Member - std::Dynamic - std::Vector;

	{
		class: scoper::Class #\,
		cache: Cache &
	}:	ScopeItem(class, cache),
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
					Fields += :create(<<scoper::MemberVariable#\>>(member), cache);
				CASE :function:
					Functions += :create(<scoper::MemberFunction#\>(member), cache);
				CASE :constructor:
					Constructors += :create(<scoper::Constructor#\>(member), cache);
				CASE :destructor:
					Destructor := :create(<scoper::Destructor#\>(member), cache);
				CASE :enum, :typedef, :class, :rawtype, :union:
					Types += :gc(Member::create(member, cache));
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
		class: scoper::GlobalClass #\,
		cache: Cache &
	}:	Class(class, cache);
}

::rlc::resolver MemberClass -> Member, Class
{
	{
		class: scoper::MemberClass #\,
		cache: Cache &
	}:	Class(class, cache),
		Member(class);
}