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
	) ast::[Config]Member-std::DynOpt
	{
		parse_visibility(p, default_visibility, TRUE);

		templates: TemplateDecl (BARE);
		parse_template_decl(p, templates);

		visibility ::= parse_visibility(p, default_visibility, FALSE);
		attr ::= parse_attribute(p);

		ret: ast::[Config]Member-std::DynOpt;

		pos ::= p.position();

		IF(parse_impl(p, ret, typedef::parse_member)
		|| ((allow_abstract_fn || !p.match(:abstract))
			&& (ret := abstractable::parse(p)))
		|| (ret := parse_constructor(p))
		|| (attr == :static
			?? <BOOL>(ret := variable::parse_member(p, TRUE))
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
				IF(t ::= <<ast::[Config]Templateable *>>(ret))
					t->Templates := &&templates;
				ELSE IF(fn ::= <<ast::[Config]Function *>>(ret))
					fn->set_templates_after_parsing(&&templates);
				ELSE IF(templates.exists())
					p.fail("preceding member must not have templates");
			}
			ret->Attribute := attr;

			IF(s ::= <<ast::[Config]ScopeItem *>>(ret))
				s->Position := pos;
		}

		= &&ret;
	}

	parse_class_member(
		p: Parser &,
		default_visibility: Visibility &
	) ast::[Config]Member-std::DynOpt
		:= parse_generic(p, default_visibility, TRUE, TRUE);

	parse_union_member(
		p: Parser &,
		default_visibility: Visibility &
	) ast::[Config]Member - std::DynOpt
		:= parse_generic(p, default_visibility, TRUE, FALSE);

	parse_rawtype_member(
		p: Parser &,
		default_visibility: Visibility &
	) ast::[Config]Member - std::DynOpt
		:= parse_generic(p, default_visibility, FALSE, FALSE);

	parse_mask_member(
		p: Parser &,
		default_visibility: Visibility &
	) ast::[Config]Member-std::DynOpt
		:= parse_generic(p, default_visibility, FALSE, FALSE);

	[T:TYPE] parse_impl(
		p: Parser &,
		ret: ast::[Config]Member-std::DynOpt &,
		parse_fn: ((Parser &, T! &) BOOL)) BOOL
	{
		v: T := BARE;
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
		IF(p.consume(:static))
			= :static;
		IF(p.consume(:hash))
			IF(p.consume(:questionMark))
				= :maybeIsolated;
			ELSE
				= :isolated;
		= :none;
	}
}