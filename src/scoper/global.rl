INCLUDE "../parser/global.rl"
INCLUDE "scopeitem.rl"

::rlc::scoper Global VIRTUAL -> VIRTUAL ScopeItem
{
	TYPE Type := parser::Global::Type;

	# ABSTRACT type() Global::Type;
	# FINAL category() ScopeItem::Category := ScopeItem::Category::global;

	STATIC create(
		parsed: parser::Global #\,
		file: src::File #&,
		group: detail::ScopeItemGroup \) Global \
		:= detail::create_global(parsed, file, group);
}