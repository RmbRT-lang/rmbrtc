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
	maybeIsolated,
	static
}

::rlc::ast [Stage:TYPE] Member VIRTUAL
{
	Visibility: rlc::Visibility;
	Attribute: rlc::MemberAttribute;

	{} (BARE);

	<<<
		g: [Stage::Prev+]Member #&,
		ctx: Stage::Context+ &
	>>> THIS - std::Dyn
	{
		= NULL;
	}
}