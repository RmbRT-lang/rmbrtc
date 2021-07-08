INCLUDE "../scoper/global.rl"
INCLUDE "scopeitem.rl"

::rlc::resolver Global VIRTUAL
{
	STATIC create(
		v: scoper::Global #\
	) Global \ := detail::create_global(v);
}