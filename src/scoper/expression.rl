INCLUDE "../parser/expression.rl"

::rlc::scoper TYPE ExpressionType := parser::ExpressionType;

::rlc::scoper Expression VIRTUAL
{
	# ABSTRACT type() ExpressionType;

	Position: UM;

	VIRTUAL set_position_impl(p: UM) VOID {}
	set_position(position: UM) VOID
	{
		Position := position;
		set_position_impl(position);
	}

	{}: Position(0);
	{position: UM}: Position(position);

	<<<
		parsed: parser::Expression #\,
		file: src::File#&
	>>> INLINE Expression \ := <<<Expression>>>(0, parsed, file);

	<<<
		position: UM,
		parsed: parser::Expression #\,
		file: src::File#&
	>>> INLINE Expression \
		:= detail::expression_create(position, parsed, file);
}