INCLUDE "../scoper/union.rl"
INCLUDE "member.rl"
INCLUDE "type.rl"

::rlc::resolver Union VIRTUAL -> ScopeItem
{
	Fields: MemberVariable - std::DynVector;
	Functions: MemberFunction - std::DynVector;

	{v: scoper::Union #\, cache: Cache &}
	->	ScopeItem(v, cache)
	{
		FOR(group ::= v->Items.start(); group; ++group)
			FOR(item ::= (*group)->Items.start(); item; ++item)
			{
				member # ::= <<scoper::Member #\>>(&**item);
				TYPE SWITCH(member)
				{
				CASE scoper::MemberVariable:
					Fields += :create(<scoper::MemberVariable #\>(member), cache);
				CASE scoper::MemberFunction:
					Functions += :create(<scoper::MemberFunction #\>(member), cache);
				DEFAULT:
					THROW <std::err::Unimplemented>(TYPE(member));
				}
			}
	}
}

::rlc::resolver GlobalUnion -> Global, Union
{
	{union: scoper::GlobalUnion #\, cache: Cache &}
	->	Union(union, cache);
}

::rlc::resolver MemberUnion -> Member, Union
{
	{union: scoper::MemberUnion #\, cache: Cache &}
	->	Member(union),
		Union(union, cache);
}