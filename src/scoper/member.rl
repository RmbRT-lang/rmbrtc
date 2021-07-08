INCLUDE "../parser/member.rl"
INCLUDE "scopeitem.rl"

::rlc::scoper Member VIRTUAL
{
	Visibility: rlc::Visibility;
	Attribute: rlc::MemberAttribute;

	{parsed: parser::Member #\}:
		Visibility(parsed->Visibility),
		Attribute(parsed->Attribute);

	STATIC create(
		parsed: parser::Member #\,
		file: src::File #&,
		group: detail::ScopeItemGroup \) Member \
		:= detail::create_member(parsed, file, group);
}