INCLUDE "../parser/typedef.rl"

::rlc::scoper Typedef -> VIRTUAL ScopeItem
{
	Type: std::[scoper::Type]Dynamic;

	CONSTRUCTOR(
		parsed: parser::Typedef #\,
		file: src::File#&,
		group: detail::ScopeItemGroup \):
		Type(scoper::Type::create(parsed->Type, file));
}

::rlc::scoper GlobalTypedef -> Global, Typedef
{
	# FINAL type() Global::Type := Global::Type::typedef;

	CONSTRUCTOR(
		parsed: parser::GlobalTypedef #\,
		file: src::File#&,
		group: detail::ScopeItemGroup \):
		ScopeItem(group, parsed, file),
		Typedef(parsed, file, group);
}

::rlc::scoper MemberTypedef -> Member, Typedef
{
	# FINAL type() Member::Type := Member::Type::typedef;

	CONSTRUCTOR(
		parsed: parser::MemberTypedef #\,
		file: src::File#&,
		group: detail::ScopeItemGroup \):
		ScopeItem(group, parsed, file),
		Member(parsed),
		Typedef(parsed, file, group);
}