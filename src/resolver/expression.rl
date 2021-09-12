INCLUDE "../scoper/expression.rl"
INCLUDE "../scoper/scope.rl"

::rlc::resolver Expression VIRTUAL
{
	<<<
		scope: scoper::Scope #\,
		ref: scoper::Expression #\
	>>> Expression \ := detail::create_expression(scope, ref);
}