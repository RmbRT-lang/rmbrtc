INCLUDE "../global.rl"
INCLUDE "../member.rl"
INCLUDE "../variable.rl"

::rlc::resolver::detail create_scope_item(
	scoped: scoper::ScopeItem #\
) ScopeItem \
{
	IF(it ::= <<scoper::Global #\>>(scoped))
		RETURN <<ScopeItem \>>(Global::create(it));
	ELSE IF(it ::= <<scoper::Member #\>>(scoped))
		RETURN <<ScopeItem \>>(Member::create(it));
	ELSE IF(it ::= <<scoper::LocalVariable #\>>(scoped))
		RETURN <<ScopeItem \>>(std::[LocalVariable]new(it));
	ELSE
		THROW <std::err::Unimplemented>(scoped->type().NAME());
}