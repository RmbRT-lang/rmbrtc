INCLUDE "../scoper/global.rl"
INCLUDE "scopeitem.rl"

::rlc::resolver Global VIRTUAL
{
	<<<
		v: scoper::Global #\,
		cache: Cache &
	>>> Global \ := detail::create_global(v, cache);
}