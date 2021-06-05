INCLUDE "../parser/extern.rl"

INCLUDE "global.rl"
INCLUDE "../util/dynunion.rl"

::rlc::scoper ExternSymbol -> Global, VIRTUAL ScopeItem
{
	Symbol: util::[GlobalVariable; GlobalFunction]DynUnion;

	# FINAL type() Global::Type := :externSymbol;

	# is_variable() INLINE BOOL := Symbol.is_first();
	# variable() INLINE GlobalVariable \ := Symbol.first();
	# is_function() INLINE BOOL := Symbol.is_second();
	# function() INLINE GlobalFunction \ := Symbol.second();

	{
		parsed: parser::ExternSymbol #\,
		file: src::File #&,
		group: detail::ScopeItemGroup \}:
		ScopeItem(group, parsed, file)
	{
		IF(parsed->is_variable())
			Symbol := std::[GlobalVariable]new(parsed->variable(), file, group);
		ELSE
			Symbol := std::[GlobalFunction]new(parsed->function(), file, group);
	}
}