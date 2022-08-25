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

	:transform{
		p: [Stage::Prev+]Member #&
	}:
		Visibility := p.Visibility,
		Attribute := p.Attribute;

	<<<
		g: [Stage::Prev+]Member #\,
		f: Stage::PrevFile+,
		s: Stage &
	>>> THIS - std::Dyn;
}