INCLUDE "scopeitem.rl"
INCLUDE "parser.rl"

::rlc ENUM Visibility
{
	public,
	protected,
	private
}

::rlc ENUM MemberAttribute
{
	none,
	isolated,
	static
}

::rlc::parser Member -> VIRTUAL ScopeItem
{
	# FINAL category() ScopeItem::Category := ScopeItem::Category::member;

	Visibility: rlc::Visibility;
	Attribute: rlc::MemberAttribute;

	ENUM Type
	{
		typedef,
		function,
		variable,
		class,
		rawtype,
		union,
		enum,
		enumConstant,
		constructor,
		destructor
	}

	# ABSTRACT type() Member::Type;

	STATIC parse(
		p: Parser&,
		default_visibility: rlc::Visibility &
	) Member * := detail::parse_member(p, default_visibility);

	STATIC parse_no_vars(
		p: Parser&,
		default_visibility: rlc::Visibility &
	) Member * := detail::parse_member_no_vars(p, default_visibility);
}