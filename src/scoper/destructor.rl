INCLUDE "../parser/destructor.rl"

::rlc::scoper Destructor -> Member, ScopeItem
{
	Body: BlockStatement;
	Inline: BOOL;

	{
		parsed: parser::Destructor #\,
		file: parser::File#&,
		group: detail::ScopeItemGroup \
	}->	Member(parsed),
		ScopeItem(group, parsed, file)
	:	Body(0, &parsed->Body, file, group->Scope),
		Inline(parsed->Inline);
}