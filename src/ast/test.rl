INCLUDE "global.rl"
INCLUDE "scopeitem.rl"
INCLUDE "statement.rl"
INCLUDE "codeobject.rl"

::rlc::ast [Stage:TYPE] Test -> [Stage]Global, CodeObject
{
	Name: Stage::String;
	Body: [Stage]BlockStatement;
}