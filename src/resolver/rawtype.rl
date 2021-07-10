INCLUDE "../scoper/rawtype.rl"
INCLUDE "expression.rl"
INCLUDE "member.rl"
INCLUDE "typedef.rl"
INCLUDE "type.rl"

::rlc::resolver Rawtype VIRTUAL -> ScopeItem
{
	# FINAL type() ScopeItem::Type := :rawtype;

	Size: Expression - std::Dynamic;
	Constructors: Constructor - std::DynVector;
	Functions: MemberFunction - std::DynVector;
	Others: Member - std::DynVector;

	{
		rawtype: scoper::Rawtype #\,
		cache: Cache &
	}->	ScopeItem(rawtype, cache)
	:	Size(:gc(Expression::create(rawtype->parent_scope(), rawtype->Size)))
	{
		FOR(group ::= rawtype->Items.start(); group; ++group)
			FOR(it ::= (*group)->Items.start(); it; ++it)
			{
				member # ::= <<scoper::Member #\>>(&**it);
				SWITCH((*it)->type())
				{
				CASE :constructor:
					Constructors += :create(<scoper::Constructor #\>(member), cache);
				CASE :function:
					Functions += :create(<scoper::MemberFunction #\>(member), cache);
				DEFAULT:
					Others += :gc(Member::create(member, cache));
				}
			}
	}
}

::rlc::resolver GlobalRawtype -> Global, Rawtype
{
	{
		rawtype: scoper::GlobalRawtype #\,
		cache: Cache &
	}->	Rawtype(rawtype, cache);
}


::rlc::resolver MemberRawtype -> Member, Rawtype
{
	{
		rawtype: scoper::MemberRawtype #\,
		cache: Cache&
	}->	Member(rawtype),
		Rawtype(rawtype, cache);
}