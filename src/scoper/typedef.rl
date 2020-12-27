INCLUDE "../parser/typedef.rl"

::rlc::scoper Typedef -> VIRTUAL ScopeItem
{
	Type: std::[scoper::Type]Dynamic;

	{
		parsed: parser::Typedef #\,
		file: src::File#&,
		group: detail::ScopeItemGroup \
	}:
		Type(:gc(scoper::Type::create(parsed->Type, file)));
}

::rlc::scoper GlobalTypedef -> Global, Typedef
{
	# FINAL type() Global::Type := :typedef;

	{
		parsed: parser::GlobalTypedef #\,
		file: src::File#&,
		group: detail::ScopeItemGroup \
	}:
		ScopeItem(group, parsed, file),
		Typedef(parsed, file, group);
}

::rlc::scoper MemberTypedef -> Member, Typedef
{
	# FINAL type() Member::Type := :typedef;

	{
		parsed: parser::MemberTypedef #\,
		file: src::File#&,
		group: detail::ScopeItemGroup \
	}:
		ScopeItem(group, parsed, file),
		Member(parsed),
		Typedef(parsed, file, group);
}