INCLUDE "../src/file.rl"
INCLUDE "../tokeniser/token.rl"

::rlc::ast [Stage: TYPE] ControlLabel -> CodeObject
{
	(// Identifier or string. /)
	Name: Stage::ControlLabelName;

	{
		name: Stage::ControlLabelName,
		position: src::Position
	} -> (position):
		Name := name;

	:transform{
		p: [Stage::Prev+]ControlLabel #&,
		ctx: Stage::Context+ #&
	} -> (p):
		Name := ctx.transform_control_label_name(p.Name);
}