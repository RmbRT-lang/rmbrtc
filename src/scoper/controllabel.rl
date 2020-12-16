INCLUDE "../parser/controllabel.rl"

INCLUDE "types.rl"

::rlc::scoper ControlLabel
{
	Exists: bool;
	Label: String;

	{
		parsed: parser::ControlLabel#&,
		file: src::File#&}:
		Exists(parsed.Exists)
	{
		IF(Exists)
			Label := file.content(parsed.Name.Content);
	}
}