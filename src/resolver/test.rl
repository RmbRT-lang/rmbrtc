INCLUDE "../scoper/test.rl"
INCLUDE "detail/statement.rl"

::rlc::resolver Test -> Global, ScopeItem
{
	# FINAL type() ScopeItem::Type := :test;

	Body: BlockStatement;

	{test: scoper::Test #\}:
		ScopeItem(test),
		Body(&test->Body);
}