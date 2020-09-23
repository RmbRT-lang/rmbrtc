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
		default_visibility: rlc::Visibility &
	) Member *
	{
		parse_visibility(p, default_visibility, TRUE);
		templates: TemplateDecl;
		templates.parse(p);
		visibility ::= parse_visibility(p, default_visibility, FALSE);
		ret: Member * := NULL;

		IF([MemberTypedef]parse_member_impl(p, ret)
		|| [MemberFunction]parse_member_impl(p, ret)
		|| [MemberVariable]parse_member_impl(p, ret)
		|| [MemberClass]parse_member_impl(p, ret)
		|| [MemberRawtype]parse_member_impl(p, ret)
		|| [MemberUnion]parse_member_impl(p, ret)
		|| [MemberEnum]parse_member_impl(p, ret)
		|| [Constructor]parse_member_impl(p, ret)
		|| [Destructor]parse_member_impl(p, ret))
		{
			ret->Visibility := visibility;
			ret->Templates := __cpp_std::move(templates);
		}

		RETURN ret;
	}

	parse_member_no_vars(
		p: Parser &,
		default_visibility: rlc::Visibility &) Member *
	{
		parse_visibility(p, default_visibility, TRUE);
		templates: TemplateDecl;
		templates.parse(p);
		visibility ::= parse_visibility(p, default_visibility, FALSE);
		ret: Member * := NULL;

		IF([MemberTypedef]parse_member_impl(p, ret)
		|| [MemberFunction]parse_member_impl(p, ret)
		|| [MemberClass]parse_member_impl(p, ret)
		|| [MemberRawtype]parse_member_impl(p, ret)
		|| [MemberUnion]parse_member_impl(p, ret)
		|| [MemberEnum]parse_member_impl(p, ret)
		|| [Constructor]parse_member_impl(p, ret)
		|| [Destructor]parse_member_impl(p, ret))
		{
			ret->Visibility := visibility;
			ret->Templates := __cpp_std::move(templates);
		}

		RETURN ret;
	}

	[T:TYPE] parse_member_impl(p: Parser &, ret: Member * &) bool
	{
		v: T;
		IF(v.parse(p))
		{
			ret := std::dup(__cpp_std::move(v));
			RETURN TRUE;
		}
		RETURN FALSE;
	}

	parse_visibility(
		p: Parser&,
		default_visibility: rlc::Visibility &,
		global: bool
	) rlc::Visibility
	{
		STATIC lookup: std::[tok::Type, rlc::Visibility]Pair#[](
			std::pair(tok::Type::public, Visibility::public),
			std::pair(tok::Type::protected, Visibility::protected),
			std::pair(tok::Type::private, Visibility::private));

		visibility ::= default_visibility;

		IF(global != p.match_ahead(tok::Type::colon))
			RETURN visibility;

		DO(found ::= FALSE)
		{
			FOR(i ::= 0; i < ::size(lookup); i++)
				IF(found := p.consume(lookup[i].First))
				{
					visibility := lookup[i].Second;
					BREAK;
				}
		} FOR(found && p.consume(tok::Type::colon);
			default_visibility := visibility)

		RETURN visibility;
	}
}