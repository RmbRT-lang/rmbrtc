INCLUDE 'std/string'
INCLUDE 'std/vector'
INCLUDE 'std/optional'

::rlc::compiler
{
	ENUM BuildType
	{
		executable,
		library,
		sharedLibrary,
		test,
		checkSyntax,
		createAST,
		verifySimple,
		verifyFull
	}

	Build
	{
		Output: std::Str - std::Opt;
		Type: BuildType;
		Debug: BOOL;
		IncludePaths: std::Str-std::Vec;
		Verbose: BOOL;

		(//
			Temporary option, do not manually access unless to enable.
			This option merges all processed file scopes into one to work around the bootstrap compiler's limitations on circular includes.
		/)
		LegacyScoping: BOOL;

		{type: BuildType} INLINE:
			Type(type)
		{
			SWITCH(type) {
			:checkSyntax, :createAST, :verifySimple, :verifyFull: {;}
			DEFAULT: THROW "build flag: invalid no-output build type";
			}

			load_include_dirs();
		}

		:withOutput{output: std::Str, type: BuildType}:
			Output(:a(&&output)),
			Type(type)
		{
			load_include_dirs();
		}

		/// Loads default include directories from the environment variable.
		PRIVATE load_include_dirs() VOID
		{
			incs ::= std::str::view(detail::getenv("RLINCLUDE"));
			DO(len: UM)
			{
				FOR(len := 0; len < ##incs; len++)
					IF(incs[len] == ':')
						BREAK;

				IF(len)
					IncludePaths += incs.cut(len)++;
			} FOR(len < ##incs; incs := incs.drop_start(len+1)++)
		}
	}

	MASK Compiler
	{
		(//
			Compiles the given input files according to the specified build flags.
		/)
		compile(
			files: std::Str - std::Vec,
			build: Build
		) VOID;
	}

	::detail EXTERN getenv(CHAR #*) CHAR # *;
}