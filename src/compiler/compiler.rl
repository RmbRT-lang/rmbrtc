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
		verifySimple,
		verifyFull
	}

	Build
	{
		Output: std::Utf8 - std::Opt;
		Type: BuildType;
		Debug: BOOL;
		AdditionalIncludePaths: std::Utf8-std::Vector;
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
			:checkSyntax, :verifySimple, :verifyFull: {;}
			DEFAULT: THROW "build flag: invalid no-output build type";
			}
		}

		:withOutput{output: std::Utf8, type: BuildType}:
			Output(:some(&&output)),
			Type(type);
	}

	MASK Compiler
	{
		(//
			Compiles the given input files according to the specified build flags.
		/)
		compile(
			files: std::Utf8 - std::Vector,
			build: Build
		) VOID;
	}
}