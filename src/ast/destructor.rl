INCLUDE "statement.rl"

::rlc::ast [Stage: TYPE] Destructor -> [Stage]Member
{
	Body: [Stage]BlockStatement;
	Inline: BOOL;
}