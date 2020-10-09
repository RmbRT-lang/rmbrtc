INCLUDE "../parser/destructor.rl"

::rlc::scoper Destructor -> Member, VIRTUAL ScopeItem
{
	Body: BlockStatement;
	Inline: bool;

	# FINAL type() Member::Type := Member::Type::destructor;

	CONSTRUCTOR(
		parsed: parser::Destructor #\,
		file: src::File#&,
		group: detail::ScopeItemGroup \):
		Member(parsed),
		ScopeItem(group, parsed, file),
		Body(0, &parsed->Body, file, group->Scope),
		Inline(parsed->Inline);
}