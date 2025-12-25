::rlc::compiler::include
{
	ENUM IncludeType
	{
		global,
		relative
	}

	Include {
		Type: IncludeType;
		BasePath: os::fs::DirectoryPath;
		Path: os::fs::FilePath;
		From: WHERE;

		{...};
	}

	::detail no_alloc(U8, VOID *) VOID * := NULL;

	/// Finds a file belonging to a global include path.
	find_global(
		path: os::fs::FilePath #&,
		globals: os::fs::DirectoryPath[#]) TAGGED os::fs::ResolveResult
	{
		file_buf: CHAR[4096];

		FOR(globals)
		{
			IF:!(rel ::= os::fs::resolve_relative(IT, path))
				CONTINUE;

			IF:!(len ::= rel->to_c_path(file_buf))
				term::error(HERE, "path too long");

			file ::= file_buf[FOR len];

			a: os::fs::UserAlloc (detail::no_alloc, NULL);
			IF:!(result ::= os::fs::ReadFile(>file, &a))
				CONTINUE;

			IF(result.(0) == :Memory)
				= rel;
		}

		= :Error;
	}
}