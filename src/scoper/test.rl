INCLUDE "../parser/test.rl"
INCLUDE "global.rl"
INCLUDE "scopeitem.rl"

::rlc::scoper Test -> Global, ScopeItem
{
	Body: BlockStatement;

	{
		parsed: parser::Test #\,
		file: parser::File #&,
		group: detail::ScopeItemGroup \
	}->	ScopeItem(group, parsed, file)
	:	Body(0, &parsed->Body, file, group->Scope);
}