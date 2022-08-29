INCLUDE "global.rl"

::rlc::ast [Config: TYPE] File
{
	/// The file's includes.
	Includes: Config::Includes;
	/// The file's global scope.
	Globals: Config::RootScope;

	Source: src::File # - std::Shared #;

	/// Used for transforming a file from the previous stage's representation.
	:transform{
		prev: Config::PrevFile #&,
		s: Config &
	}:
		Source := prev->Source
	{
		s.transform_includes(Includes, prev);
		s.transform_globals(Globals, prev);
	}
}