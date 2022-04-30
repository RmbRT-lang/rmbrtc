INCLUDE "scopeitem.rl"

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

::rlc::ast [Stage:TYPE] Member VIRTUAL
{
	Visibility: rlc::Visibility;
	Attribute: rlc::MemberAttribute;
}