INCLUDE "../scoper/mask.rl"
INCLUDE "function.rl"
INCLUDE "type.rl"
INCLUDE "scopeitem.rl"

::rlc::resolver Mask VIRTUAL -> ScopeItem
{
	// Functions that other types must implement.
	AbstractFunctions: MemberFunction - std::DynVector;
	// Functions that the mask already implements itself.
	Functions: MemberFunction - std::DynVector;
	Others: Member - std::DynVector;


	{mask: scoper::Mask #\, cache: Cache &}->
		ScopeItem(mask, cache)
	{
		FOR(group ::= mask->Items.start(); group; ++group)
			FOR(item ::= (*group)->Items.start(); item; ++item)
			{
				member # ::= <<scoper::Member #\>>(&**item);
				TYPE SWITCH(member)
				{
				CASE scoper::MemberFunction:
				{
					fn ::= <scoper::MemberFunction #\>(member);
					IF(fn->Attribute != :static
					&& !fn->Body)
					{
						AbstractFunctions += :create(fn, cache);
						AbstractFunctions.back()->Abstractness := :abstract;
					} ELSE
						Functions += :create(fn, cache);
				}
				DEFAULT:
					Others += :gc(<<<Member>>>(member, cache));
				}
			}
	}

}

::rlc::resolver GlobalMask -> Global, Mask
{
	{mask: scoper::GlobalMask #\, cache: Cache &}->
		Mask(mask, cache);
}