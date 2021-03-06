INCLUDE "../global.rl"
INCLUDE "../namespace.rl"
INCLUDE "../typedef.rl"
INCLUDE "../mask.rl"
INCLUDE "../variable.rl"
INCLUDE "../function.rl"
INCLUDE "../test.rl"

::rlc::parser::detail
{
	parse_global(p: Parser &) Global *
	{
		templates: TemplateDecl;
		templates.parse(p);

		ret: Global * := NULL;
		IF([Namespace]parse_global_impl(p, ret)
		|| [GlobalTypedef]parse_global_impl(p, ret)
		|| [GlobalFunction]parse_global_impl(p, ret)
		|| [GlobalVariable]parse_global_impl(p, ret)
		|| [GlobalClass]parse_global_impl(p, ret)
		|| [GlobalMask]parse_global_impl(p, ret)
		|| [GlobalRawtype]parse_global_impl(p, ret)
		|| [GlobalEnum]parse_global_impl(p, ret)
		|| [ExternSymbol]parse_global_impl(p, ret)
		|| (!templates.exists() && [Test]parse_global_impl(p, ret)))
		{
			<<ScopeItem \>>(ret)->Templates := &&templates;
		}

		RETURN ret;
	}

	[T: TYPE] parse_global_impl(p: Parser &, ret: Global * &) BOOL
	{
		v: T;
		IF(v.parse(p))
		{
			ret := std::dup(&&v);
			RETURN TRUE;
		}
		RETURN FALSE;
	}
}