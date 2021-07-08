INCLUDE "../member.rl"
INCLUDE "../variable.rl"
INCLUDE "../typedef.rl"
INCLUDE "../type.rl"
INCLUDE "../function.rl"
INCLUDE "../class.rl"
INCLUDE "../rawtype.rl"
INCLUDE "../union.rl"
INCLUDE "../enum.rl"
INCLUDE "../extern.rl"
INCLUDE "../constructor.rl"
INCLUDE "../destructor.rl"

::rlc::parser::detail
{
	parse_member(
		p: Parser&,
		default_visibility: Visibility &
	) Member *
	{
		templates: TemplateDecl;
		visibility: Visibility;
		attr: MemberAttribute;
		parse_member_intro(p, default_visibility, visibility, templates, attr);
		ret: Member * := NULL;

		IF([MemberTypedef]parse_member_impl(p, ret)
		|| [MemberFunction]parse_member_impl(p, ret)
		|| [Constructor]parse_member_impl(p, ret)
		|| (parse_member_variable(p, ret, attr == :static))
		|| [MemberClass]parse_member_impl(p, ret)
		|| [MemberRawtype]parse_member_impl(p, ret)
		|| [MemberUnion]parse_member_impl(p, ret)
		|| [MemberEnum]parse_member_impl(p, ret)
		|| [Destructor]parse_member_impl(p, ret))
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

	parse_member_no_vars(
		p: Parser &,
		default_visibility: Visibility &) Member *
	{
		templates: TemplateDecl;
		visibility: Visibility;
		attr: MemberAttribute;
		parse_member_intro(p, default_visibility, visibility, templates, attr);
		ret: Member * := NULL;

		IF([MemberTypedef]parse_member_impl(p, ret)
		|| [MemberFunction]parse_member_impl(p, ret)
		|| [Constructor]parse_member_impl(p, ret)
		|| (attr == :static
			&& parse_member_variable(p, ret, TRUE))
		|| [MemberClass]parse_member_impl(p, ret)
		|| [MemberRawtype]parse_member_impl(p, ret)
		|| [MemberUnion]parse_member_impl(p, ret)
		|| [MemberEnum]parse_member_impl(p, ret)
		|| [Destructor]parse_member_impl(p, ret))
		{
			ret->Visibility := visibility;
			<<ScopeItem \>>(ret)->Templates := &&templates;
			ret->Attribute := attr;
		}

		RETURN ret;
	}

	parse_mask_member(
		p: Parser &,
		default_visibility: Visibility &) Member *
	{
		templates: TemplateDecl;
		visibility: Visibility;
		attr: MemberAttribute;
		parse_member_intro(p, default_visibility, visibility, templates, attr);
		ret: Member * := NULL;

		IF([MemberTypedef]parse_member_impl(p, ret)
		|| (p.match(:identifier) // Ignore abstract functions.
			&& [MemberFunction]parse_member_impl(p, ret))
		|| (attr == :static && parse_member_variable(p, ret, TRUE))
		|| [MemberClass]parse_member_impl(p, ret)
		|| [MemberRawtype]parse_member_impl(p, ret)
		|| [MemberUnion]parse_member_impl(p, ret)
		|| [MemberEnum]parse_member_impl(p, ret)
		|| [Constructor]parse_member_impl(p, ret))
		{
			ret->Visibility := visibility;
			<<ScopeItem \>>(ret)->Templates := &&templates;
			ret->Attribute := attr;
		}

		RETURN ret;
	}

	parse_member_variable(p: Parser &, ret: Member * &, static: BOOL) BOOL
	{
		v: std::[MemberVariable]Dynamic := :gc(std::[MemberVariable]new());
		IF(v->parse(p, static))
		{
			ret := v.release();
			RETURN TRUE;
		}
		RETURN FALSE;
	}

	[T:TYPE] parse_member_impl(p: Parser &, ret: Member * &) BOOL
	{
		v: T;
		IF(v.parse(p))
		{
			ret := std::dup(&&v);
			RETURN TRUE;
		}
		RETURN FALSE;
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