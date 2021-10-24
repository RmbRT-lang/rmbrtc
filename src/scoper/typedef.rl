INCLUDE "../parser/typedef.rl"

::rlc::scoper Typedef VIRTUAL -> ScopeItem
{
	Type: std::[scoper::Type]Dynamic;

	{
		parsed: parser::Typedef #\,
		file: parser::File#&,
		group: detail::ScopeItemGroup \
	}->	ScopeItem(group, parsed, file)
	:	Type(:gc(<<<scoper::Type>>>(parsed->Type, file.Src)));
}

::rlc::scoper GlobalTypedef -> Global, Typedef
{
	{
		parsed: parser::GlobalTypedef #\,
		file: parser::File#&,
		group: detail::ScopeItemGroup \
	}->	Typedef(parsed, file, group);
}

::rlc::scoper MemberTypedef -> Member, Typedef
{
	{
		parsed: parser::MemberTypedef #\,
		file: parser::File#&,
		group: detail::ScopeItemGroup \
	}->	Member(parsed),
		Typedef(parsed, file, group);
}