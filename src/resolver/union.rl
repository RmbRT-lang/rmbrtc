INCLUDE "../scoper/union.rl"
INCLUDE "member.rl"
INCLUDE "type.rl"

::rlc::resolver Union VIRTUAL -> ScopeItem
{
	# FINAL type() ScopeItem::Type := :union;

	Fields: MemberVariable - std::Vector;
	Functions: MemberFunction - std::Vector;

	{v: scoper::Union #\}:
		ScopeItem(v)
	{
		FOR(group ::= v->Items.start(); group; ++group)
			FOR(item ::= (*group)->Items.start(); item; ++item)
			{
				member # ::= <<scoper::Member #\>>(&**item);
				SWITCH(type ::= (*item)->type())
				{
				CASE :variable:
					Fields += <scoper::MemberVariable #\>(member);
				CASE :function:
					Functions += <scoper::MemberFunction #\>(member);
				DEFAULT:
					THROW <std::err::Unimplemented>(type.NAME());
				}
			}
	}
}

::rlc::resolver GlobalUnion -> Global, Union
{
	{union: scoper::GlobalUnion #\}:
		Union(union);
}

::rlc::resolver MemberUnion -> Member, Union
{
	{union: scoper::MemberUnion #\}:
		Member(union),
		Union(union);
}