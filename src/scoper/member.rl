INCLUDE "../parser/member.rl"
INCLUDE "scopeitem.rl"

::rlc::scoper Member VIRTUAL -> VIRTUAL ScopeItem
{
	Visibility: rlc::Visibility;
	Attribute: rlc::MemberAttribute;

	TYPE Type := parser::Member::Type;

	# ABSTRACT type() Member::Type;
	# FINAL category() ScopeItem::Category := ScopeItem::Category::member;

	{parsed: parser::Member #\}:
		Visibility(parsed->Visibility),
		Attribute(parsed->Attribute);

	STATIC create(
		parsed: parser::Member #\,
		file: src::File #&,
		group: detail::ScopeItemGroup \) Member \
		:= detail::create_member(parsed, file, group);
}