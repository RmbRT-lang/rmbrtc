::rlc ENUM Visibility
{
	public,
	protected,
	private
}

::rlc::parser Member -> VIRTUAL ScopeItem
{
	# FINAL category() ScopeItem::Category := ScopeItem::Category::member;
	Visibility: rlc::Visibility;

	ENUM Type
	{
		typedef,
		function,
		variable,
		class
	}

	# ABSTRACT type() Member::Type;

	STATIC parse(
		p: Parser&,
		default_visibility: rlc::Visibility &
	) Member *
	{
		visibility ::= parse_visibility(p, default_visibility);
		ret: Member * := NULL;

		IF([MemberTypedef]parse_impl(p, ret)
		|| [MemberFunction]parse_impl(p, ret)
		|| [MemberVariable]parse_impl(p, ret)
		|| [MemberClass]parse_impl(p, ret))
			ret->Visibility := visibility;

		RETURN ret;
	}

	STATIC parse_no_vars(
		p: Parser&,
		default_visibility: rlc::Visibility &
	) Member *
	{
		visibility ::= parse_visibility(p, default_visibility);
		ret: Member * := NULL;

		IF([MemberTypedef]parse_impl(p, ret)
		|| [MemberFunction]parse_impl(p, ret)
		|| [MemberClass]parse_impl(p, ret))
			ret->Visibility := visibility;

		RETURN ret;
	}

PRIVATE:
	[T:TYPE]
	STATIC parse_impl(p: Parser &, ret: Member * &) bool
	{
		v: T;
		IF(v.parse(p))
		{
			ret := std::dup(__cpp_std::move(v));
			RETURN TRUE;
		}
		RETURN FALSE;
	}

	STATIC parse_visibility(
		p: Parser&,
		default_visibility: rlc::Visibility &
	) rlc::Visibility
	{
		STATIC lookup: std::[tok::Type, rlc::Visibility]Pair#[](
			std::pair(tok::Type::public, Visibility::public),
			std::pair(tok::Type::protected, Visibility::protected),
			std::pair(tok::Type::private, Visibility::private));

		visibility ::= default_visibility;

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