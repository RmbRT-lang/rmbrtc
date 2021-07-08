INCLUDE "../scoper/rawtype.rl"
INCLUDE "expression.rl"
INCLUDE "member.rl"
INCLUDE "typedef.rl"
INCLUDE "type.rl"

::rlc::resolver Rawtype VIRTUAL -> ScopeItem
{
	# FINAL type() ScopeItem::Type := :rawtype;

	Size: Expression - std::Dynamic;
	Constructors: Constructor - std::Vector;
	Functions: MemberFunction - std::Vector;
	Others: Member - std::Dynamic - std::Vector;

	{
		rawtype: scoper::Rawtype #\
	}:	ScopeItem(rawtype),
		Size(:gc(Expression::create(rawtype->parent_scope(), rawtype->Size)))
	{
		FOR(group ::= rawtype->Items.start(); group; ++group)
			FOR(it ::= (*group)->Items.start(); it; ++it)
			{
				member # ::= <<scoper::Member #\>>(&**it);
				SWITCH((*it)->type())
				{
				CASE :constructor:
					Constructors += <scoper::Constructor #\>(member);
				CASE :function:
					Functions += <scoper::MemberFunction #\>(member);
				DEFAULT:
					Others += :gc(Member::create(member));
				}
			}
	}
}

::rlc::resolver GlobalRawtype -> Global, Rawtype
{
	{
		rawtype: scoper::GlobalRawtype #\
	}:	Rawtype(rawtype);
}


::rlc::resolver MemberRawtype -> Member, Rawtype
{
	{
		rawtype: scoper::MemberRawtype #\
	}:	Member(rawtype),
		Rawtype(rawtype);
}