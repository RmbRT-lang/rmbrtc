INCLUDE "../parser/expression.rl"

::rlc::scoper Expression VIRTUAL
{
	Position: UM;

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