INCLUDE "typedef.rl"
INCLUDE "function.rl"
INCLUDE "constructor.rl"
INCLUDE "variable.rl"
INCLUDE "class.rl"
INCLUDE "rawtype.rl"
INCLUDE "union.rl"
INCLUDE "enum.rl"
INCLUDE "destructor.rl"
INCLUDE "templatedecl.rl"


::rlc::parser::member
{
	parse_generic(
		p: Parser&,
		default_visibility: Visibility &,
		allow_variable: BOOL,
		allow_abstract_fn: BOOL
	) ast::[Config]Member-std::Dyn
	{
		parse_visibility(p, default_visibility, TRUE);

		templates: TemplateDecl;
		parse_template_decl(p, templates);

		visibility ::= parse_visibility(p, default_visibility, FALSE);
		attr ::= parse_attribute(p);

		ret: ast::[Config]Member-std::Dyn := NULL;

		IF(parse_impl(p, ret, typedef::parse_member)
		|| ((allow_abstract_fn || !p.match(:abstract))
			&& (ret := abstractable::parse(p)))
		|| (ret := parse_constructor(p))
		|| (attr == :static
			? (ret := variable::parse_member(p, TRUE))
			: allow_variable && (ret := variable::parse_member(p, FALSE)))
		|| (attr == :none && parse_impl(p, ret, function::parse_factory))
		|| parse_impl(p, ret, class::parse_member)
		|| parse_impl(p, ret, rawtype::parse_member)
		|| parse_impl(p, ret, union::parse_member)
		|| parse_impl(p, ret, enum::parse_member)
		|| parse_impl(p, ret, destructor::parse))
		{
			ret->Visibility := visibility;
			IF(templates.exists())
			{
				IF:!(t ::= <<ast::[Config]Templateable *>>(ret))
					p.fail("preceding member must not have templates");
				t->Templates := &&templates;
			}
			ret->Attribute := attr;
		}

		= &&ret;
	}

	parse_class_member(
		p: Parser &,
		default_visibility: Visibility &
	) ast::[Config]Member-std::Dyn
		:= parse_generic(p, default_visibility, TRUE, TRUE);

	parse_union_member(
		p: Parser &,
		default_visibility: Visibility &
	) ast::[Config]Member - std::Dyn
		:= parse_generic(p, default_visibility, TRUE, FALSE);

	parse_rawtype_member(
		p: Parser &,
		default_visibility: Visibility &
	) ast::[Config]Member - std::Dyn
		:= parse_generic(p, default_visibility, FALSE, FALSE);

	parse_mask_member(
		p: Parser &,
		default_visibility: Visibility &
	) ast::[Config]Member-std::Dyn
		:= parse_generic(p, default_visibility, FALSE, FALSE);

	[T:TYPE] parse_impl(
		p: Parser &,
		ret: ast::[Config]Member-std::Dyn &,
		parse_fn: ((Parser &, T! &) BOOL)) BOOL
	{
		v: T;
		IF(!parse_fn(p, v))
			= FALSE;
		ret := :dup(&&v);
		= TRUE;
	}

	parse_visibility(
		p: Parser&,
		default_visibility: Visibility &,
		global: BOOL
	) Visibility
	{
		STATIC lookup: {tok::Type, Visibility}#[](
			(:public, :public),
			(:protected, :protected),
			(:private, :private));

		visibility ::= default_visibility;

		IF(global != p.match_ahead(:colon))
			RETURN visibility;

		DO(found ::= FALSE)
		{
			FOR(i ::= 0; i < ##lookup; i++)
				IF(found := p.consume(lookup[i].(0)))
				{
					visibility := lookup[i].(1);
					BREAK;
				}
		} FOR(found && p.consume(:colon);
			default_visibility := visibility)

		RETURN visibility;
	}

	parse_attribute(
		p: Parser &) MemberAttribute
	{
		STATIC lookup: {tok::Type, MemberAttribute}#[](
			(:static, :static),
			(:hash, :isolated));

		FOR(i ::= 0; i < ##lookup; i++)
			IF(p.consume(lookup[i].(0)))
				RETURN lookup[i].(1);

		RETURN :none;
	}
}