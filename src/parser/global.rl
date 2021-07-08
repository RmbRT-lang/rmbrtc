INCLUDE "parser.rl"
INCLUDE "scopeitem.rl"

::rlc::parser Global VIRTUAL
{
	STATIC parse(p: Parser &) Global * := detail::parse_global(p);
}