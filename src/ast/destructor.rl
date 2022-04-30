INCLUDE "statement.rl"

::rlc::ast [Stage: TYPE] Destructor -> Member
{
	Body: [Stage]BlockStatement;
	Inline: BOOL;
}