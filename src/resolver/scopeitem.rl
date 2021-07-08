INCLUDE "../scoper/scopeitem.rl"

::rlc::resolver ScopeItem VIRTUAL
{
	TYPE Type := scoper::ScopeItem::Type;
	# ABSTRACT type() Type;

	Name: scoper::String;

	{scopeItem: scoper::ScopeItem #\}:
		Name(scopeItem->name());

	STATIC create(
		scoped: scoper::ScopeItem #\
	) ScopeItem \ := detail::create_scope_item(scoped);
}