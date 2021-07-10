INCLUDE "../parser/namespace.rl"

INCLUDE "global.rl"
INCLUDE "scopeitem.rl"

::rlc::scoper Namespace -> ScopeItem, Global, Scope
{
	# FINAL type() ScopeItem::Type := :namespace;

	{
		parsed: parser::Namespace #\,
		file: src::File#&,
		group: detail::ScopeItemGroup \
	}->	ScopeItem(group, parsed, file),
		Scope(&THIS, group->Scope)
	{
		FOR(i ::= 0; i < ##parsed->Entries; i++)
			Scope::insert(parsed->Entries[i], file);
	}
}