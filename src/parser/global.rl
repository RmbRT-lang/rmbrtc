INCLUDE "parser.rl"
INCLUDE "scopeitem.rl"
(/INCLUDE "namespace.rl"
INCLUDE "typedef.rl"
INCLUDE "variable.rl"
INCLUDE "function.rl"/)

::rlc::parser Global -> VIRTUAL ScopeItem
{
	ENUM Type
	{
		namespace,
		typedef,
		function,
		variable,
		class,
		rawtype
	}
	# ABSTRACT type() Global::Type;
	# FINAL category() ScopeItem::Category := ScopeItem::Category::global;

	STATIC parse(p: Parser &) Global *
	{
		templates: TemplateDecl;
		templates.parse(p);

		ret: Global * := NULL;
		IF([Namespace]parse_impl(p, ret)
		|| [GlobalTypedef]parse_impl(p, ret)
		|| [GlobalFunction]parse_impl(p, ret)
		|| [GlobalVariable]parse_impl(p, ret)
		|| [GlobalClass]parse_impl(p, ret)
		|| [GlobalRawtype]parse_impl(p, ret))
		{
			ret->Templates := __cpp_std::move(templates);
		}

		RETURN ret;
	}

PRIVATE:
	[T: TYPE]
	STATIC parse_impl(p: Parser &, ret: Global * &) bool
	{
		v: T;
		IF(v.parse(p))
		{
			ret := ::std::dup(__cpp_std::move(v));
			RETURN TRUE;
		}
		RETURN FALSE;
	}
}