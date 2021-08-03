INCLUDE "../scoper/statement.rl"
INCLUDE "../scoper/scope.rl"

::rlc::resolver Statement VIRTUAL
{
	TYPE Type := scoper::StatementType;

	# ABSTRACT type() Type;

	Position: UM;

	{stmt: scoper::Statement #\}: Position(stmt->Position);

	<<<
		stmt: scoper::Statement #\,
		cache: Cache &
	>>> Statement \ := detail::create_statement(stmt, cache);
}