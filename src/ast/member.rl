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
		m: [Stage::Prev+]Member #&,
		ctx: Stage::Context+ #&
	>>> THIS - std::Val
	{
		TYPE SWITCH(m)
		{
		[Stage::Prev+]MemberClass:
			= :a.[Stage]MemberClass(:transform(
				<<[Stage::Prev+]MemberClass #&>>(m), ctx));
		[Stage::Prev+]MemberRawtype:
			= :a.[Stage]MemberRawtype(:transform(
				<<[Stage::Prev+]MemberRawtype #&>>(m), ctx));
		[Stage::Prev+]Abstractable:
			= :<>(<<<[Stage]Abstractable>>>(
				<<[Stage::Prev+]Abstractable #&>>(m), ctx));
		[Stage::Prev+]Factory:
			= :a.[Stage]Factory(:transform(
				<<[Stage::Prev+]Factory #&>>(m), ctx));
		[Stage::Prev+]Constructor:
			= :<>(<<<[Stage]Constructor>>>(
				<<[Stage::Prev+]Constructor #&>>(m), ctx));
		[Stage::Prev+]Destructor:
			= :a.[Stage]Destructor(:transform(
				<<[Stage::Prev+]Destructor #&>>(m), ctx));
		[Stage::Prev+]MemberEnum:
			= :a.[Stage]MemberEnum(:transform(
				<<[Stage::Prev+]MemberEnum #&>>(m), ctx));
		[Stage::Prev+]MaybeAnonMemberVar:
			= :<>(<<<[Stage]MaybeAnonMemberVar>>>(
				<<[Stage::Prev+]MaybeAnonMemberVar #&>>(m), ctx));
		[Stage::Prev+]MemberTypedef:
			= :a.[Stage]MemberTypedef(:transform(
				<<[Stage::Prev+]MemberTypedef #&>>(m), ctx));
		[Stage::Prev+]MemberUnion:
			= :a.[Stage]MemberUnion(:transform(
				<<[Stage::Prev+]MemberUnion #&>>(m), ctx));
		}
	}
}