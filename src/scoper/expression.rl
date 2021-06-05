INCLUDE "../parser/expression.rl"

::rlc::scoper TYPE ExpressionType := parser::ExpressionType;

::rlc::scoper Expression VIRTUAL
{
	# ABSTRACT type() ExpressionType;

	Position: UM;

	{}: Position(0);
	{position: UM}: Position(position);

	STATIC create(
		parsed: parser::Expression #\,
		file: src::File#&
	) INLINE Expression \ := create(0, parsed, file);

	STATIC create(
		position: UM,
		parsed: parser::Expression #\,
		file: src::File#&
	) INLINE Expression \
		:= detail::expression_create(position, parsed, file);
}