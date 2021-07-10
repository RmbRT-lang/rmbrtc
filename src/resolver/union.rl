INCLUDE "../scoper/union.rl"
INCLUDE "member.rl"
INCLUDE "type.rl"

::rlc::resolver Union VIRTUAL -> ScopeItem
{
	# FINAL type() ScopeItem::Type := :union;

	Fields: MemberVariable - std::DynVector;
	Functions: MemberFunction - std::DynVector;

	{v: scoper::Union #\, cache: Cache &}
	->	ScopeItem(v, cache)
	{
		FOR(group ::= v->Items.start(); group; ++group)
			FOR(item ::= (*group)->Items.start(); item; ++item)
			{
				member # ::= <<scoper::Member #\>>(&**item);
				SWITCH(type ::= (*item)->type())
				{
				CASE :variable:
					Fields += :create(<scoper::MemberVariable #\>(member), cache);
				CASE :function:
					Functions += :create(<scoper::MemberFunction #\>(member), cache);
				DEFAULT:
					THROW <std::err::Unimplemented>(type.NAME());
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