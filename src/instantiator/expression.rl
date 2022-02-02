INCLUDE "../resolver/expression.rl"

::rlc::instantiator Expression VIRTUAL
{
	<<<
		expr: resolver::Expression #\,
		scope: Scope #&
	>>> Expression \ := detail::create_expression(expr, scope);
}