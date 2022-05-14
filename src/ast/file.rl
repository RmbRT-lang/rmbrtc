INCLUDE "global.rl"

::rlc::ast [Config: TYPE] File
{
	/// The file's includes.
	Includes: Config::Includes;
	/// The file's global scope.
	Globals: Config::RootScope;

	Name: std::Str;
	Source: src::File# \;

	/// Used for transforming a file from the previous stage's representation.
	:transform{
		prev: Config::PrevFile #&,
		ctx: Config \
	}
	{
		ctx->transform_includes(Includes, prev);
		ctx->transform_globals(Globals, prev);
	}
}