INCLUDE "parser.rl"
INCLUDE "stage.rl"
INCLUDE "templatedecl.rl"
INCLUDE "class.rl"

::rlc::parser::global
{
	parse(p: Parser &) ast::[Config]Global - std::Dyn
	{
		templates: TemplateDecl;
		templates.parse(p);

		ret: ast::[Config]Global - std::Dyn := NULL;
		IF(parse_global_impl(p, ret, namespace::parse)
		|| parse_global_impl(p, ret, typedef::parse)
		|| parse_global_impl(p, ret, function::parse)
		|| parse_global_impl(p, ret, variable::parse_global)
		|| parse_global_impl(p, ret, class::parse)
		|| parse_global_impl(p, ret, mask::parse)
		|| parse_global_impl(p, ret, rawtype::parse)
		|| parse_global_impl(p, ret, enum::parse)
		|| parse_global_impl(p, ret, extern::parse)
		|| (!templates.exists() && parse_global_impl(p, ret, test::parse)))
		{
			IF(t ::= <<[Config]Templateable *>>(ret!))
				t->Templates := &&templates;
			ELSE
				ASSERT(!templates.exists());
		}

		RETURN ret;
	}

	[T: TYPE] parse_global_impl(
		p: Parser &,
		ret: ast::[Config]Global - std::Dyn &,
		parse_fn: ((Parser &, T! &) BOOL)
	) BOOL
	{
		v: T;
		succ: BOOL;
		IF(succ := parse_fn(p, v))
			ret := :dup(&&v);
		= succ;
	}
}