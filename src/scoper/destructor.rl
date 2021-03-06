INCLUDE "../parser/destructor.rl"

::rlc::scoper Destructor -> Member, ScopeItem
{
	Body: BlockStatement;
	Inline: BOOL;

	# FINAL type() ScopeItem::Type := :destructor;

	{
		parsed: parser::Destructor #\,
		file: src::File#&,
		group: detail::ScopeItemGroup \
	}->	Member(parsed),
		ScopeItem(group, parsed, file)
	:	Body(0, &parsed->Body, file, group->Scope),
		Inline(parsed->Inline);
}