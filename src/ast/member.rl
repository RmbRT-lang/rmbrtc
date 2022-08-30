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

	{...};

	:transform{
		p: [Stage::Prev+]Member #&
	}:
		Visibility := p.Visibility,
		Attribute := p.Attribute;

	<<<
		g: [Stage::Prev+]Member #\,
		f: Stage::PrevFile+,
		s: Stage &
	>>> THIS - std::Dyn
	{
		TYPE SWITCH(g)
		{
		[Stage::Prev+]MemberClass:
			= :dup(<[Stage]MemberClass>(:transform(
				<<[Stage::Prev+]MemberClass #&>>(*g), f, s)));
		[Stage::Prev+]MemberRawtype:
			= :dup(<[Stage]MemberRawtype>(:transform(
				<<[Stage::Prev+]MemberRawtype #&>>(*g), f, s)));
		[Stage::Prev+]Abstractable:
			= <<<[Stage]Abstractable>>>(
				<<[Stage::Prev+]Abstractable #\>>(g), f, s);
		[Stage::Prev+]Factory:
			= :dup(<[Stage]Factory>(:transform(
				<<[Stage::Prev+]Factory #&>>(*g), f, s)));
		[Stage::Prev+]Constructor:
			= <<<[Stage]Constructor>>>(<<[Stage::Prev+]Constructor #\>>(g), f, s);
		[Stage::Prev+]MemberEnum:
			= :dup(<[Stage]MemberEnum>(:transform(
				<<[Stage::Prev+]MemberEnum #&>>(*g), f, s)));
		[Stage::Prev+]MaybeAnonMemberVar:
			= <<<[Stage]MaybeAnonMemberVar>>>(
				<<[Stage::Prev+]MaybeAnonMemberVar #\>>(g), f, s);
		[Stage::Prev+]MemberTypedef:
			= :dup(<[Stage]MemberTypedef>(:transform(
				<<[Stage::Prev+]MemberTypedef #&>>(*g), f, s)));
		[Stage::Prev+]MemberUnion:
			= :dup(<[Stage]MemberUnion>(:transform(
				<<[Stage::Prev+]MemberUnion #&>>(*g), f, s)));
		}
	}
}