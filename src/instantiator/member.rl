INCLUDE "../resolver/member.rl"

::rlc::instantiator Member VIRTUAL
{
	Attribute: rlc::MemberAttribute;
	Visibility: rlc::Visibility;

	<<<
		res: resolver::Member #\,
		scope: Scope #&
	>>> Member \ := detail::create_member(res, scope);
}