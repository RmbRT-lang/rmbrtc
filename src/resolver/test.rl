INCLUDE "../scoper/test.rl"
INCLUDE "detail/statement.rl"

::rlc::resolver Test -> Global, ScopeItem
{
	Body: BlockStatement;

	{test: scoper::Test #\, cache: Cache &}->
		ScopeItem(test, cache)
	:	Body(&test->Body, cache);
}