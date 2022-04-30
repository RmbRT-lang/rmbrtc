INCLUDE "typedef.rl"
INCLUDE "function.rl"
INCLUDE "constructor.rl"
INCLUDE "variable.rl"
INCLUDE "class.rl"
INCLUDE "union.rl"
INCLUDE "enum.rl"
INCLUDE "destructor.rl"


::rlc::parser::member
{
	parse(
		p: Parser&,
		default_visibility: rlc::Visibility &
	) ast::[Config]Member-std::Dyn
		:= parse_opt_var(p, default_visibility, TRUE);

	parse_no_vars(
		p: Parser&,
		default_visibility: rlc::Visibility &
	) ast::[Config]Member-std::Dyn
		:= parse_opt_var(p, default_visibility, FALSE);

	parse_generic(
		p: Parser&,
		default_visibility: Visibility &,
		allow_variable: BOOL,
		allow_abstract_fn: BOOL
	) ast::[Config]Member-std::Dyn
	{
		templates: TemplateDecl;
		visibility: Visibility;
		attr: MemberAttribute;
		parse_member_intro(p, default_visibility, visibility, templates, attr);
		ret: ast::[Config]Member-std::Dyn := NULL;

		IF(parse_impl(p, ret, typedef::parse_member)
		|| ((allow_abstract_fn || p.match(:abstract))
			&& parse_impl(p, ret, abstractable::parse_member_function))
		|| parse_impl(p, ret, constructor::parse)
		|| (attr == :static
			? parse_impl(p, ret, variable::parse_static_member)
			: allow_variable && parse_impl(p, ret, variable::parse_member))
		|| parse_impl(p, ret, class::parse_member)
		|| parse_impl(p, ret, rawtype::parse_member)
		|| parse_impl(p, ret, union::parse_member)
		|| parse_impl(p, ret, enum::parse_member)
		|| parse_impl(p, ret, destructor::parse))
		{
			ret->Visibility := visibility;
			<<ScopeItem \>>(ret)->Templates := &&templates;
			ret->Attribute := attr;
		}

		RETURN ret;
	}

	parse_member_intro(
		p: Parser &,
		default_visibility: Visibility &,
		visibility: Visibility &,
		templates: TemplateDecl &,
		attribute: MemberAttribute &) VOID
	{
		parse_visibility(p, default_visibility, TRUE);
		templates.parse(p);
		visibility := parse_visibility(p, default_visibility, FALSE);

		attribute := parse_attribute(p);
	}

	parse_mask_member(
		p: Parser &,
		default_visibility: Visibility &) ast::[Config]Member-std::Dyn
	{
		templates: TemplateDecl;
		visibility: Visibility;
		attr: MemberAttribute;
		parse_member_intro(p, default_visibility, visibility, templates, attr);
		ret: ast::[Config]Member-std::Dyn := NULL;

		IF([MemberTypedef]parse_impl(p, ret)
		|| (p.match(:identifier) // Ignore abstract functions.
			&& [MemberFunction]parse_impl(p, ret))
		|| (attr == :static && parse_member_variable(p, ret, TRUE))
		|| [MemberClass]parse_impl(p, ret)
		|| [MemberRawtype]parse_impl(p, ret)
		|| [MemberUnion]parse_impl(p, ret)
		|| [MemberEnum]parse_impl(p, ret)
		|| [Constructor]parse_impl(p, ret))
		{
			ret->Visibility := visibility;
			<<ScopeItem \>>(ret)->Templates := &&templates;
			ret->Attribute := attr;
		}

		RETURN ret;
	}

	parse_member_variable(p: Parser &, ret: ast::[Config]Member-std::Dyn &, static: BOOL) BOOL
	{
		v: MemberVariable-std::Dyn := :gc(std::[MemberVariable]new());
		IF(v->parse(p, static))
		{
			ret := v.release();
			RETURN TRUE;
		}
		RETURN FALSE;
	}

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