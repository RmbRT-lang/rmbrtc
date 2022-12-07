INCLUDE "global.rl"

::rlc::ast [Config: TYPE] File
{
	/// The file's includes.
	Includes: Config::Includes;
	/// The file's global scope.
	Globals: Config::RootScope;

	Source: src::File # - std::Shared #;

	# name() std::str::CV := Source->Name!;

	/// Used for transforming a file from the previous stage's representation.
	:transform{
		prev: Config::PrevFile #&,
		s: Config &
	}:
		Source := prev->Source
	{
		ASSERT(Source);
		s.transform_includes(Includes, &THIS, prev);
		s.transform_globals(Globals, prev);
	}
}