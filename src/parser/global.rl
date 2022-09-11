INCLUDE "parser.rl"
INCLUDE "stage.rl"
INCLUDE "templatedecl.rl"
INCLUDE "class.rl"
INCLUDE "mask.rl"
INCLUDE "extern.rl"
INCLUDE "test.rl"
INCLUDE "namespace.rl"

::rlc::parser::global
{
	parse(p: Parser &) ast::[Config]Global - std::Dyn
	{
		templates: TemplateDecl (BARE);
		parse_template_decl(p, templates);

		pos ::= p.position();

		ret: ast::[Config]Global - std::Dyn := NULL;
		IF(parse_global_impl(p, ret, namespace::parse)
		|| parse_global_impl(p, ret, typedef::parse_global)
		|| parse_global_impl(p, ret, function::parse_global)
		|| (ret := variable::parse_global(p))
		|| parse_global_impl(p, ret, class::parse_global)
		|| parse_global_impl(p, ret, mask::parse_global)
		|| parse_global_impl(p, ret, rawtype::parse_global)
		|| parse_global_impl(p, ret, enum::parse_global)
		|| (ret := extern::parse(p))
		|| parse_global_impl(p, ret, test::parse))
		{
			IF(t ::= <<ast::[Config]Templateable *>>(ret!))
				t->Templates := &&templates;
			ELSE IF(fn ::= <<ast::[Config]Function *>>(ret!))
				fn->set_templates_after_parsing(&&templates);
			ELSE IF(templates.exists())
				p.fail("preceding item must not have templates");

			IF(s ::= <<ast::[Config]ScopeItem *>>(ret!))
				s->Position := pos;
		}

		RETURN ret;
	}

	[T: TYPE] parse_global_impl(
		p: Parser &,
		ret: ast::[Config]Global - std::Dyn &,
		parse_fn: ((Parser &, T! &) BOOL)
	) BOOL
	{
		v: T := BARE;
		succ: BOOL;
		IF(succ := parse_fn(p, v))
			ret := :dup(&&v);
		= succ;
	}
}