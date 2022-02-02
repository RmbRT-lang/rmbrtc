INCLUDE "../resolver/statement.rl"

::rlc::instantiator Statement VIRTUAL
{
	<<<
		stmt: resolver::Statement #\,
		scope: VOID*
	>>> Statement \ := detail::create_statement(stmt, scope);
}