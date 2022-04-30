INCLUDE "../src/file.rl"
INCLUDE "../tokeniser/token.rl"

::rlc::ast [Stage: TYPE] ControlLabel -> CodeObject
{
	{}:
		Exists(FALSE);

	Exists: BOOL;
	(// Identifier or string. /)
	Name: Stage::ControlLabelName;
}