INCLUDE "../scoper/scopeitem.rl"
INCLUDE 'std/map'
INCLUDE 'std/tags'

::rlc::resolver ScopeItem VIRTUAL
{
	std::NoMove; // Don't move because of Cache's pointer tracking.
	std::NoCopy;

	TYPE Type := scoper::ScopeItem::Type;
	# ABSTRACT type() Type;

	Name: scoper::String;


	{scopeItem: scoper::ScopeItem #\, cache: Cache &}:
		Name(scopeItem->name())
	{
		cache += (scopeItem, &THIS);
	}


	STATIC create(
		scoped: scoper::ScopeItem #\,
		cache: Cache &
	) ScopeItem \ := detail::create_scope_item(scoped, cache);
}


::rlc::resolver Cache
{
	Resolved: std::[scoper::ScopeItem #\, ScopeItem #\, Cache]Map;

	insert(scoped: scoper::ScopeItem #\) VOID
		{ insert(scoped, ScopeItem::create(scoped, THIS)); }
	THIS+=(v: scoper::ScopeItem #\) INLINE VOID
		{ insert(v); }

	insert(scoped: scoper::ScopeItem #\, resolved: ScopeItem #\) VOID
	{ 
		IF(!Resolved.find(scoped))
			ASSERT(Resolved.insert(scoped, resolved));
	}
	THIS+=(v: {scoper::ScopeItem #\, ScopeItem #\}) INLINE VOID
		{ insert(v.(0), v.(1)); }

	[T:TYPE] STATIC cmp(a: T, b: T!) ::= a-b;
}