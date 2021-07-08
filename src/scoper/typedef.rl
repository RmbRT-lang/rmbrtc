INCLUDE "../parser/typedef.rl"

::rlc::scoper Typedef VIRTUAL -> ScopeItem
{
	# FINAL type() ScopeItem::Type := :typedef;

	Type: std::[scoper::Type]Dynamic;

	{
		parsed: parser::Typedef #\,
		file: src::File#&,
		group: detail::ScopeItemGroup \
	}:	ScopeItem(group, parsed, file),
		Type(:gc(scoper::Type::create(parsed->Type, file)));
}

::rlc::scoper GlobalTypedef -> Global, Typedef
{
	{
		parsed: parser::GlobalTypedef #\,
		file: src::File#&,
		group: detail::ScopeItemGroup \
	}:	Typedef(parsed, file, group);
}

::rlc::scoper MemberTypedef -> Member, Typedef
{
	{
		parsed: parser::MemberTypedef #\,
		file: src::File#&,
		group: detail::ScopeItemGroup \
	}:	Member(parsed),
		Typedef(parsed, file, group);
}