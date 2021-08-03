INCLUDE "../parser/global.rl"
INCLUDE "scopeitem.rl"

::rlc::scoper Global VIRTUAL
{
	<<<
		parsed: parser::Global #\,
		file: src::File #&,
		group: detail::ScopeItemGroup \
	>>> Global \
		:= detail::create_global(parsed, file, group);
}