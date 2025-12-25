INCLUDE 'std/string'
INCLUDE 'std/vector'
INCLUDE 'std/optional'

INCLUDE "srcloader.rl"
INCLUDE "includes.rl"

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
		BasePath: os::fs::DirectoryPath;
		Output: std::Str - std::Opt;
		Type: BuildType;
		Debug: BOOL;
		IncludePaths: os::fs::DirectoryPath-std::Vec;
		Verbose: BOOL;
		EntryPoints: std::Str - std::Vec;

		(//
			Temporary option, do not manually access unless to enable.
			This option merges all processed file scopes into one to work around the bootstrap compiler's limitations on circular includes.
		/)
		LegacyScoping: BOOL;
		SINGLE_THREADED: BOOL;

		{type: BuildType} INLINE:
			Type(type),
			BasePath(:dir(os::fs::current_dir()))
		{
			SWITCH(type)
			{
			:checkSyntax, :createAST, :verifySimple, :verifyFull: {;}
			DEFAULT: THROW "build flag: invalid no-output build type"!;
			}

			load_include_dirs();
		}

		:withOutput{output: std::Str, type: BuildType}:
			Output(:a(&&output)),
			Type(type),
			BasePath(:dir(os::fs::current_dir()))
		{
			load_include_dirs();
		}

		/// Loads default include directories from the environment variable.
		PRIVATE load_include_dirs() VOID
		{
			incs_c ::= detail::getenv("RLINCLUDE"!);
			STATIC keepalive: std::Str := incs_c[FOR std::str::len(incs_c[])];
			incs ::= keepalive!;
			DO(len: UM)
			{
				FOR(len := 0; len < ##incs; len++)
					IF(incs[len] == ':')
						BREAK;

				IF(len)
				{
					term::info(NULL, "Include dir: ", incs[UNTIL len]);
					IncludePaths += :dir(incs[UNTIL len]);
				}
			} FOR(len < ##incs; incs := incs[AFTER len])

			SINGLE_THREADED := std::str::eq(std::str::c(detail::getenv("RLC_ST"!)[]), "1");

			term::info(NULL,
				"SINGLE_THREADED: ", SINGLE_THREADED ?? "TRUE"[#] : "FALSE"[#]);
		}
	}

	Compiler
	{
		(/ Compiler architecture:

		compile() thread     |    loader thread    |  parser thread
		       --- [X] invocation files --->
		       <-- [X] load source files ---
		       --- [X] parsed includes ---->
		       <-- [X] more source files ---
		                 ...

		       -------------------- [/] token streams ------->
		                           ...
		       <--- [ ] scope trees + IR0 -----------------------

		       [ ] merge scopes
		       [ ] resolve IR0 to IR1 from the scopes
		       [ ] typecheck IR1
		       [ ] instantiate into IR2
		       [ ] codegen

		IR0: unresolved references
		IR1: resolved references, no template instantiation, partial typechecking
		IR2: templates instantiated, full typechecking
		codegen: machine code (or RASM), which no longer contains types.
		codegen2?: final machine code.
		/)

		(//
			Compiles the given input files according to the specified build flags.
		/)
		compile(
			files: std::Str#[#],
			build: Build
		) VOID
		{
			start_time ::= NOW;

			load_files(files!, build);

			IF(build.Type == :checkSyntax)
				RETURN;

			{
				size ::= 0;
				FOR(src::fileContents!)
					size += ##IT;
				end_time ::= NOW;

				term::info(NULL, "loaded ", std::io::format::dec(##src::fileNames), " files (", std::io::format::dec(size), " bytes in ", std::io::format::dec((end_time - start_time) / 1000000), ".", std::io::format::dec_x((end_time - start_time) % 1000000 / 1000, 3), "ms).");
			}

			(/ TODO:
				- [X] factor out include parsing.
				- [X] resolve include paths.
				- [X] tokenise included files.
				- [X] debug tempalloc.
				- [/] write scope tree (status check)
				- [/] write parser
				- [ ] write AST merger? Actually just let the parser write into the global AST (rather: scope tree) directly.
				- [ ] resolver
				- [ ] IR -- this is part of the parser already somewhat.
				- [ ] type check & instantiator
				- [ ] code gen /)


			
			/// Parse included files.

			IF(build.Type == :createAST)
				RETURN;

			/// Seed instantiator with items to process.
			SWITCH(build.Type)
			{
			:verifySimple: RETURN;
			:executable:
			{
				//entry ::= build.EntryPoints.start();
				//Instantiator!.generate_entry_point_by_name(entry ?? entry! : "main");
			}
			:library,
			:sharedLibrary:
			{
				(/IF(entry ::= build.EntryPoints.start())
					FOR(entry) Instantiator!.generate_entry_point_by_name(entry!);
				ELSE
					Instantiator!.generate_everything();/)
			}
			:test:
			{
				//Instantiator!.generate_tests();
			}
			:verifyFull:
			{
				//Instantiator!.generate_everything();
			}
			}

			IF(!build.Output)
				RETURN;
			DIE "outputs not implemented";
		}
	}

	load_files(files: std::Str#[#], build: Build #&) VOID
	{
		includes: rlc::tok::Token - std::Vec := :reserve(2048);

		fileTokens: rlc::tok::FileTokens;
			fileTokens.Types.reserve(32*1024*16);
			fileTokens.STypes.reserve(32*1024*16);
			fileTokens.Payloads.reserve(32*1024*16);
			fileTokens.Positions.reserve(32*1024*16);


		queue: include::Include- std::Vec := :bare(2048);
		outputs: TAGGED SrcLoader::Result -std::Vec := :bare(2048);

		loader: SrcLoader (build.BasePath, >build.IncludePaths!);
		loader_pipe: [SrcLoader]Pipeline(queue!, outputs!, &loader);

		FOR(files) loader_pipe.issue(:relative(build.BasePath, IT!, NULL));

		IF!(build.SINGLE_THREADED)
		{
			loader_pipe.Threaded := TRUE;
			STATIC loading_thread ::= ^loader_pipe.worker_thread();
		}

		fileNames: std::temp::Alloc := :custom(1<<16, 1 << 12);

		/// Parse all code first.
		WHILE(processed ::= loader_pipe.get_some())
		{
			FOR(processed)
			{
				IF:!(result ::= IT)
					CONTINUE;

				includes.clear_reuse();
				fileTokens.Types.clear_reuse();
				fileTokens.STypes.clear_reuse();
				fileTokens.Payloads.clear_reuse();

				f ::= result!.File;
				contents ::= result!.Content;

				// Parse includes.
				tokeniser: rlc::tok::Tokeniser(f, contents);

				first_token ::= compiler::parse_includes(includes, tokeniser);

				basefile: os::fs::FilePath := result!.Name;

				// Do not load includes if we are to only check the syntax of the input files.
				IF(build.Type != :checkSyntax)
				{
					// Queue all includes for the loader.
					FOR(includes!)
					{
						ASSERT(IT.Type.(0) == :String);
						loader_pipe.issue(
							IT.Type.(1).String == :StringQuote
							?? include::IncludeType::relative
							: include::IncludeType::global,
							basefile.Directory, parse_string(IT, fileNames), IT.at());
					}
				}

				IF!(first_token)
					CONTINUE;

				// Continue tokenising the files.
				DO(token ::= *first_token)
				{
					std::vec::pushback(
						(fileTokens.Types,     token.Type.(0)),
						(fileTokens.STypes,    token.Type.(1)),
						(fileTokens.Payloads,  token.Payload),
						(fileTokens.Positions, token.Position.byte()));
				} WHILE(tokeniser.parse_next(&token))
			}
		}
	}

	parse_string(str: tok::Token #&, alloc: std::temp::Alloc &) CHAR#[#]
	{
		ASSERT(str.Type.(0) == :String);
		contents ::= str.contents();
		SWITCH(t ::= str.Type.(1).String)
		{
		:StringQuote, :StringApostrophe:
			contents := contents[FROM 1 UNTIL ##contents-1];
		DEFAULT:
			term::error(HERE, "unhandled string type: ", std::str::enum(t));
		}

		buffer ::= <CHAR *>(alloc.alloc_raw_unaligned(##contents))[];

		o ::= 0;
		FOR(i ::= 0; i < ##contents; i++)
		{
			IF(contents[i] != '\\')
			{
				buffer[o++] := contents[i];
				CONTINUE;
			}

			SWITCH(ch ::= contents[++i])
			{
			'\\': buffer[o++] := '\\';
			'x', 'X': {
				IF(##contents <= i+2) term::error(str.at(), "Contains unfinished hex sequence");

				high ::= contents[++i];
				low ::= contents[++i];
				
				IF(high >= '0' && high <= '9')
					high := high - '0';
				ELSE IF(high >= 'a' && high <= 'f')
					high := high - 'a' + 0xa;
				ELSE IF(high >= 'A' && high <= 'F')
					high := high - 'A' + 0xa;
				ELSE term::error(str.at(), "invalid hex sequence");

				IF(low >= '0' && low <= '9')
					low := low - '0';
				ELSE IF(low >= 'a' && low <= 'f')
					low := low - 'a' + 0xa;
				ELSE IF(low >= 'A' && low <= 'F')
					low := low - 'A' + 0xa;
				ELSE term::error(str.at(), "invalid hex sequence");

				buffer[o++] := high << 4 | low;
			}
			'n': buffer[o++] := '\n';
			'r': buffer[o++] := '\r';
			't': buffer[o++] := '\t';
			'"': buffer[o++] := '"';
			'\'': buffer[o++] := '\\';
			'`': buffer[o++] := '`';
			DEFAULT:
				term::error(str.at(), "invalid escape sequence: \\", (&ch)[FOR 1]);
			}
		}

		= buffer[UNTIL o];
	}

	parse_includes(
		includes: rlc::tok::Token - std::Vec &,
		tokeniser: tok::Tokeniser &) tok::Token-std::Opt
	{
		token: rlc::tok::Token (BARE);
		IF!(tokeniser.parse_next(&token))
			= NULL;

		WHILE(token.Type.(0) == :AuxKeyword
			&& token.Type.(1).AuxKeyword == :include)
		{
			path: rlc::tok::Token (BARE);
			IF(!tokeniser.parse_next(&path))
				term::error(tokeniser.at(), "expected path after INCLUDE.");

			IF(path.Type.(0) != :String)
				term::error(path.at(), "unexpected token after include", std::str::c(<CHAR #*>(path.Type.(0))[]));
			IF(path.Type.(1).String != :StringApostrophe && path.Type.(1).String != :StringQuote)
				term::error(path.at(), "invalid string type for includes");

			added: ?& := (includes += path);

			IF!(tokeniser.parse_next(&token))
				= NULL;
		}
		= :a(token);
	}

	::detail EXTERN getenv(CHAR #*) CHAR #*;
}