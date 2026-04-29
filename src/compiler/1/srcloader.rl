INCLUDE "../pipeline.rl"

::rlc::compiler SrcLoader
{
	BasePath: os::fs::DirectoryPath;
	IncludePaths: os::fs::DirectoryPath#[#];

	{...};

	LoadedFile {
		File: src::File;
		Name: CHAR#[#];
		Content: CHAR#[#];
	}

	UNION Result
	{
	*	Duplicate;
	!?	File: LoadedFile;
	}

	TYPE Output := TAGGED Result;
	TYPE Input := include::Include;

	STATIC file_buffer: CHAR[512] (NOINIT);
	STATIC resolve_buffer: CHAR[512] (NOINIT);

	STATIC name() CHAR#[#] -- := "source code loader";

	handle_job(inc: include::Include #&, out: TAGGED Result *) BOOL
	{
		SWITCH!(inc.Type)
		{
		:global:
		{
			IF(inc.Path.Directory.IsAbsolute)
				term::error(inc.From, "global include with absolute path");

			IF!(##IncludePaths)
				term::error(inc.From, "cannot include global file: no include paths have been configured");

			FOR[try_paths](IncludePaths)
			{
				IF:!(rel ::= os::fs::resolve_relative(IT, inc.Path))
					CONTINUE;

				IF:!(unique ::= try_load_file(inc.From, *rel, out))
					= FALSE;

				IF!(status ::= *unique)
				{
					IF(status == :NotFound)
						CONTINUE [try_paths];

					file ::= file_buffer[FOR rel->to_c_path(file_buffer)];
					term::error(inc.From,
						"Could not open ", file, ": ", std::str::enum(status));
				}

				= TRUE;
			}

			file ::= resolve_buffer[FOR inc.Path.to_c_path(resolve_buffer)];
			term::error(inc.From, "Could not find global include '", file, "'.");
		}
		:relative:
		{
			IF:!(rel ::= os::fs::resolve_relative(inc.BasePath, inc.Path))
				term::error(inc.From, "Invalid relative path");

			IF:!(unique ::= try_load_file(inc.From, *rel, out))
				= FALSE;

			IF!(status ::= *unique)
			{
				file ::= file_buffer[FOR rel->to_c_path(file_buffer)];
				term::error(inc.From,
					"Could not open ", file, ": ", std::str::enum(status));
			}
		}
		}
		= TRUE;
	}

	PRIVATE try_load_file(
		at: WHERE,
		rel: os::fs::ResolvedPath,
		out: TAGGED Result *) ENUM os::fs::ReadFileResult - std::Opt
	{
		IF:!(len ::= rel.to_c_path(file_buffer))
			term::error(at, "Resolved file path too long");
		file ::= file_buffer[FOR len];

		h ::= std::hash_str(file);
		IF(src::has_file_h(h, file))
		{
			out->{:Duplicate};
			= NULL;
		}

		ctx: src::IncludeContext (NULL, file);
		alloc: os::fs::UserAlloc (&src::alloc_file_contents, &ctx);

		IF:!(result ::= os::fs::ReadFile(>file, &alloc))
			= :a(result.(0)); // Error code.

		contents ::= <CHAR*>(result!.Data)[FOR result!.Size];

		f ::= src::add_file_with_source_ok(h, file, contents);
		out->{f, >src::fileNames[f], >src::fileContents[f]};

		= :a(:Data); // "OK" code of ReadFileResult.
	}
}