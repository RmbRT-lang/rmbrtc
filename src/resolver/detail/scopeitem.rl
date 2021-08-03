INCLUDE "../global.rl"
INCLUDE "../member.rl"
INCLUDE "../variable.rl"

::rlc::resolver::detail create_scope_item(
	scoped: scoper::ScopeItem #\,
	cache: Cache &
) ScopeItem \
{
	IF(it ::= <<scoper::Global #*>>(scoped))
		RETURN <<ScopeItem \>>(<<<Global>>>(it, cache));
	ELSE IF(it ::= <<scoper::Member #*>>(scoped))
		RETURN <<ScopeItem \>>(<<<Member>>>(it, cache));
	ELSE IF(it ::= <<scoper::LocalVariable #*>>(scoped))
		RETURN <<ScopeItem \>>(std::[LocalVariable]new(it, cache));
	ELSE
		THROW <std::err::Unimplemented>(scoped->type().NAME());
}