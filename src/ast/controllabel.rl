INCLUDE "../src/file.rl"
INCLUDE "../tokeniser/token.rl"

::rlc::ast [Stage: TYPE] ControlLabel -> CodeObject
{
	(// Identifier or string. /)
	Name: Stage::ControlLabelName;

	{name: Stage::ControlLabelName}: Name(name);

	:transform{
		p: [Stage::Prev+]ControlLabel #&,
		f: Stage::PrevFile+,
		s: Stage &
	} -> (p):
		Name := s.transform_control_label_name(p.Name, f);
}