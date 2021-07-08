INCLUDE "../scoper/extern.rl"

INCLUDE "global.rl"
INCLUDE "../util/dynunion.rl"

::rlc::resolver ExternSymbol -> Global, ScopeItem
{
	Symbol: util::[GlobalVariable; GlobalFunction]DynUnion;

	# FINAL type() ScopeItem::Type := :externSymbol;

	# is_variable() INLINE BOOL := Symbol.is_first();
	# variable() INLINE GlobalVariable \ := Symbol.first();
	# is_function() INLINE BOOL := Symbol.is_second();
	# function() INLINE GlobalFunction \ := Symbol.second();

	{
		scoped: scoper::ExternSymbol #\
	}:	ScopeItem(scoped)
	{
		IF(scoped->is_variable())
			Symbol := :gc(std::[GlobalVariable]new(scoped->variable()));
		ELSE
			Symbol := :gc(std::[GlobalFunction]new(scoped->function()));
	}
}