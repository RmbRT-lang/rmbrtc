INCLUDE "../scoper/mask.rl"
INCLUDE "function.rl"
INCLUDE "type.rl"
INCLUDE "scopeitem.rl"

::rlc::resolver Mask VIRTUAL -> ScopeItem
{
	# FINAL type() ScopeItem::Type := :mask;

	// Functions that other types must implement.
	AbstractFunctions: MemberFunction - std::Vector;
	// Functions that the mask already implements itself.
	Functions: MemberFunction - std::Vector;
	Others: Member - std::Dynamic - std::Vector;


	{mask: scoper::Mask #\}:
		ScopeItem(mask)
	{
		FOR(group ::= mask->Items.start(); group; ++group)
			FOR(item ::= (*group)->Items.start(); item; ++item)
			{
				member # ::= <<scoper::Member #\>>(&**item);
				SWITCH((*item)->type())
				{
				CASE :function:
				{
					fn ::= <scoper::MemberFunction #\>(member);
					IF(fn->Attribute != :static
					&& !fn->Body)
					{
						abstract: MemberFunction(fn);
						abstract.Abstractness := :abstract;
						AbstractFunctions += &&abstract;
					} ELSE
						Functions += fn;
				}
				DEFAULT:
					Others += :gc(Member::create(member));
				}
			}
	}

}

::rlc::resolver GlobalMask -> Global, Mask
{
	{mask: scoper::GlobalMask #\}:
		Mask(mask);
}