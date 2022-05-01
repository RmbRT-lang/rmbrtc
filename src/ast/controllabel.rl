INCLUDE "../src/file.rl"
INCLUDE "../tokeniser/token.rl"

::rlc::ast [Stage: TYPE] ControlLabel -> CodeObject
{
	(// Identifier or string. /)
	Name: Stage::ControlLabelName;
}