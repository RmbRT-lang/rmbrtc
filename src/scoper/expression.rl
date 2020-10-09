INCLUDE "../parser/expression.rl"

::rlc::scoper TYPE ExpressionType := parser::ExpressionType;

::rlc::scoper Expression
{
	# ABSTRACT type() ExpressionType;

	STATIC create(
		parsed: parser::Expression #\,
		file: src::File#&
	) INLINE Expression \
		:= detail::expression_create(parsed, file);
}