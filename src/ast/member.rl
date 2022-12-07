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
		f: Stage::PrevFile+,
		s: Stage &,
		parent: [Stage]ScopeBase \
	>>> THIS - std::Dyn
	{
		TYPE SWITCH(m)
		{
		[Stage::Prev+]MemberClass:
			= :a.[Stage]MemberClass(:transform(
				<<[Stage::Prev+]MemberClass #&>>(m), f, s, parent));
		[Stage::Prev+]MemberRawtype:
			= :a.[Stage]MemberRawtype(:transform(
				<<[Stage::Prev+]MemberRawtype #&>>(m), f, s, parent));
		[Stage::Prev+]Abstractable:
			= :<>(<<<[Stage]Abstractable>>>(
				<<[Stage::Prev+]Abstractable #&>>(m), f, s, parent));
		[Stage::Prev+]Factory:
			= :a.[Stage]Factory(:transform(
				<<[Stage::Prev+]Factory #&>>(m), f, s, parent));
		[Stage::Prev+]Constructor:
			= :<>(<<<[Stage]Constructor>>>(
				<<[Stage::Prev+]Constructor #&>>(m), f, s, parent));
		[Stage::Prev+]Destructor:
			= :a.[Stage]Destructor(:transform(
				<<[Stage::Prev+]Destructor #&>>(m), f, s, parent));
		[Stage::Prev+]MemberEnum:
			= :a.[Stage]MemberEnum(:transform(
				<<[Stage::Prev+]MemberEnum #&>>(m), f, s, parent));
		[Stage::Prev+]MaybeAnonMemberVar:
			= :<>(<<<[Stage]MaybeAnonMemberVar>>>(
				<<[Stage::Prev+]MaybeAnonMemberVar #&>>(m), f, s, parent));
		[Stage::Prev+]MemberTypedef:
			= :a.[Stage]MemberTypedef(:transform(
				<<[Stage::Prev+]MemberTypedef #&>>(m), f, s, parent));
		[Stage::Prev+]MemberUnion:
			= :a.[Stage]MemberUnion(:transform(
				<<[Stage::Prev+]MemberUnion #&>>(m), f, s, parent));
		}
	}
}