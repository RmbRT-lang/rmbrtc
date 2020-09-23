INCLUDE "parser.rl"
INCLUDE "scopeitem.rl"

::rlc::parser Global -> VIRTUAL ScopeItem
{
	ENUM Type
	{
		namespace,
		typedef,
		function,
		variable,
		class,
		rawtype,
		union,
		enum,
		externSymbol
	}
	# ABSTRACT type() Global::Type;
	# FINAL category() ScopeItem::Category := ScopeItem::Category::global;

	STATIC parse(p: Parser &) Global * := detail::parse_global(p);
}