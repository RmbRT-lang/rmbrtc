INCLUDE "../parser/namespace.rl"

INCLUDE "global.rl"
INCLUDE "scopeitem.rl"

::rlc::scoper Namespace -> VIRTUAL ScopeItem, Global, Scope
{
	CONSTRUCTOR(
		parsed: parser::Namespace #\,
		file: src::File#&,
		group: detail::ScopeItemGroup \):
		ScopeItem(group, parsed, file),
		Scope(THIS, group->Scope)
	{
		FOR(i ::= 0; i < parsed->Entries.size(); i++)
			insert(parsed->Entries[i], file);
	}

	# FINAL type() Global::Type := Global::Type::namespace;
}