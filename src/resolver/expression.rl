INCLUDE "../scoper/expression.rl"
INCLUDE "../scoper/scope.rl"

::rlc::resolver Expression VIRTUAL
{
	ENUM Type
	{
		reference,
		constant,
		member,
		operator,
		cast
	}

	# ABSTRACT type() Type;

	STATIC create(
		scope: scoper::Scope #\,
		ref: scoper::Expression #\
	) Expression \ := detail::create_expression(scope, ref);
}