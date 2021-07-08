INCLUDE "../scoper/member.rl"
INCLUDE "../parser/member.rl"
INCLUDE "scopeitem.rl"

::rlc::resolver Member VIRTUAL
{
	Attribute: rlc::MemberAttribute;
	Visibility: rlc::Visibility;

	{
		m: scoper::Member #\
	}:	Attribute(m->Attribute),
		Visibility(m->Visibility);

	STATIC create(
		m: scoper::Member #\
	) Member \ := detail::create_member(m);
}