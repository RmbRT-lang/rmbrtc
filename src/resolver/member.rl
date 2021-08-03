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

	<<<
		m: scoper::Member #\,
		cache: Cache &
	>>> Member \ := detail::create_member(m, cache);
}