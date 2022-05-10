INCLUDE "global.rl"

::rlc::ast [Config: TYPE] File
{
	/// The file's includes.
	Includes: Config::Includes;
	/// The file's global scope.
	Globals: [Config]Global - std::DynVec;

	Name: std::Str;

	/// Used for transforming a file from the previous stage's representation.
	:transform{
		prev: Config::Previous #&,
		ctx: Config \
	}
	{
		ctx->transform_includes(Includes, prev);
		ctx->transform_globals(Globals, prev);
	}
}