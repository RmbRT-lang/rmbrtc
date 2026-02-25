INCLUDE 'std/string'
INCLUDE 'std/vector'
INCLUDE 'std/optional'
INCLUDE 'std/sync/race'

INCLUDE "srcloader.rl"
INCLUDE "includes.rl"
INCLUDE "codetoker.rl"
INCLUDE "codeparser.rl"
INCLUDE "iddedupler.rl"

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

		disk -------> tokeniser pool -----> parser (pool?) -----------> scope resolver
		      files                  tokens                scope, IR0

		The disk is one bottleneck, so we have only one loader thread. Tokenising is way slower than loading, so we have multiple tokenisers. Parsing is faster than tokenising, so we only need one parser, probably. We can have other threads that process the parser's output.

			If possible, we want to avoid having contention in a task that fundamentally only needs one thread. If possible, we want to split tasks into two threads of tighter, homogeneous loops, especially since we are limited by a single source loader thread, so data ingress is also a bottleneck.

		          ---> tokenise --
		         /                \                          IR
		load ---<----> tokenise --->--> preparse  ---->    parse
		         \                /    scope-assemble   local-resolve
		          ---> tokenise --                     full scope tree

		compile() thread     |    loader thread    |  tokeniser pool   |   parser
		       --- [X] invocation files --->
		       <-- [X] load source files ---
		       --- [X] parsed includes ---->
		       --- [X] source files (bodies) ----------------->
		       <-- [X] more source files ---
		       --- [X] source files (bodies) ----------------->
		                 ...

		                                                  -- [X] token streams -->
		                           ...
		       <--- [ ] scope trees + IR0 --------------------------------------

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

		Multi-tokeniser: useless, since we don't get files from disk that quickly anyway.

		Multi-parser: same thing. We do not get many files
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

			STATIC tok_pipes: [CodeTokeniser; #4]PipelineSetup[1];
				IF!(build.SINGLE_THREADED) FOR(tok_pipes) IT.launch_worker();
			STATIC tok_pipes_p: [CodeTokeniser]Pipeline *[##tok_pipes] (NOINIT);
			FOR(tok_pipes_p) IT := &tok_pipes[IOTA];

			STATIC iddedup_pipe: [IdDeDupler; #2]PipelineSetup;
				IF!(build.SINGLE_THREADED) iddedup_pipe.launch_worker();

			STATIC parser_pipes: [CodeParser; #2]PipelineSetup[1];
				IF!(build.SINGLE_THREADED) FOR(parser_pipes) IT.launch_worker();
			STATIC parser_pipes_p: [CodeParser]Pipeline *[##parser_pipes] (NOINIT);
			FOR(parser_pipes_p) IT := &parser_pipes[IOTA];

			load_files(files!, build, tok_pipes_p, iddedup_pipe, parser_pipes_p);

			FOR(tok_pipes) IT.wait_quit(HERE);
			FOR(parser_pipes) IT.wait_quit(HERE);
			iddedup_pipe.wait_quit(HERE);

			IF(build.Type == :checkSyntax)
				RETURN;

			{
				size ::= 0;
				FOR(src::fileContents!)
					size += ##IT;
				end_time ::= NOW;

				term::info(NULL, "loaded ", std::io::format::dec(##src::fileNames), " files (", std::io::format::dec(size), " bytes in ", std::io::format::dec((end_time - start_time) / 1000000), ".", std::io::format::dec_x((end_time - start_time) % 1000000 / 1000, 3), "ms). Total identifiers: ", std::io::format::dec(##ident::strings));
			}

			(/ TODO:
				- [X] factor out include parsing.
				- [X] resolve include paths.
				- [X] tokenise included files.
				- [X] debug tempalloc.
				- [X] pre-parse & dedup identifiers
				- [X] assemble scope tree
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
			//DIE "outputs not implemented";
		}
	}

	pass_along_toker_to_dedupler(
		out: CodeTokeniser::Output &,
		pipe: [IdDeDupler]Pipeline &) VOID
	{
		next_input ::= pipe.next_input();
		// Make sure the buffers can be reused.
			// IT.Tokens :=: &&next_input->Tokens;
		{
			old ::= &&next_input->Tokens;
			next_input->Tokens.{&&out.Tokens};
			out.Tokens.{&&old};
		}
		{
			old ::= &&next_input->Identifiers;
			next_input->Identifiers := &&out.Identifiers;
			out.Identifiers := &&old;
		}
		{
			old ::= &&next_input->IdHashes;
			next_input->IdHashes := &&out.IdHashes;
			out.IdHashes := &&old;
		}

		next_input->File := out.File;
		pipe.issue_flush_prepared();
	}

	pass_along_dedupler_to_preparser(
		out: IdDeDupler::Output &,
		pipe: [CodeParser]Pipeline &) VOID
	{
		next_input ::= pipe.next_input();

		next_input->File := out.File;
		next_input->LocalIds := out.LocalIds;

			// IT.Tokens :=: &&next_input->Tokens;
		(/{
			old ::= &&next_input->Tokens;
			next_input->Tokens.{&&out.Tokens};
			out.Tokens.{&&old};
		}/)
			next_input->Tokens := &&out.Tokens;

		pipe.issue_flush_prepared();
	}

	load_files(
		files: std::Str#[#],
		build: Build #&,
		tokeniser_pipes: [CodeTokeniser]Pipeline \[#],
		iddedup_pipe: [IdDeDupler]Pipeline &,
		parser_pipes: [CodeParser]Pipeline \[#]) VOID
	{
		includes: rlc::tok::Token - std::Vec := :reserve(2048);

		// Capacity: twice the max number of jobs that can be issued before polling.
		queue: include::Include- std::Vec := :bare(2048);
		outputs: TAGGED SrcLoader::Result -std::Vec := :bare(2048);

		loader: SrcLoader (build.BasePath, >build.IncludePaths!);
		loader_pipe: [SrcLoader]Pipeline(queue!, outputs!, &loader);

		FOR(files) loader_pipe.issue_flush(:relative(build.BasePath, IT!, NULL));

		loading_thread: VOID^ (NOINIT);
			IF!(build.SINGLE_THREADED) loading_thread.{ loader_pipe.launch_worker() };

		fileNames: std::temp::Alloc := :custom(1<<16, 1 << 12);

		reset: std::temp::Locals::Scope;

		tokeniser_round ::= 0;
		parser_round ::= 0;
		/// Parse all code first.
		WHILE(processed ::= loader_pipe.get_some(HERE))
		{
			FOR(processed)
			{
				IF:!(result ::= IT)
					CONTINUE;
				includes.clear_reuse();

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
						ASSERT(IT.Type == :String);
						loader_pipe.issue_flush(
							IT.SType.String == :StringQuote
							?? include::IncludeType::relative
							: include::IncludeType::global,
							basefile.Directory, parse_string(IT, fileNames), IT.at());
					}
					loader_pipe.flush();
				}
				// Issue the rest of the file to a tokeniser thread.
				IF!(first_token)
					CONTINUE;

				IF(parser_pipes[parser_round % ##parser_pipes]->full())
					parser_pipes[parser_round % ##parser_pipes]->get_some(HERE);

				i ::= tokeniser_round++ % ##tokeniser_pipes;
				IF(tokeniser_pipes[i]->full())
				{
					tokenised ::= tokeniser_pipes[i]->get_some(HERE);
					ASSERT(tokenised);
					FOR(tokenised)
					{
						IF(iddedup_pipe.full())
							FOR(iddedup_pipe.get_some(HERE))
							{
								IF(parser_pipes[parser_round % ##parser_pipes]->full())
									parser_pipes[parser_round % ##parser_pipes]->get_some(HERE);
								pass_along_dedupler_to_preparser(IT, *parser_pipes[parser_round++ % ##parser_pipes]);
							}

						pass_along_toker_to_dedupler(IT, iddedup_pipe);
					}
				}
					//tokeniser_pipes[i].get_some();
				tokeniser_pipes[i]->issue_flush(&&tokeniser, *first_token, f);
			}
		}

		loader_pipe.quit();
		loader_pipe.wait_quit(HERE);
		IF!(loading_thread[100000000])
			term::error(HERE, "Died");
		loading_thread();

		FOR(tokeniser_pipes)
		{
			WHILE(tokenised ::= IT->get_some(HERE))
				FOR(tokenised)
				{
					//BUG: ST: the queued jobs for the tokeniser do not get flushed.
					IF(iddedup_pipe.full())
						FOR(iddedup_pipe.get_some(HERE))
						{
							IF(parser_pipes[parser_round % ##parser_pipes]->full())
								parser_pipes[parser_round % ##parser_pipes]->get_some(HERE);
							pass_along_dedupler_to_preparser(IT, *parser_pipes[parser_round++ % ##parser_pipes]);
						}

					pass_along_toker_to_dedupler(IT, iddedup_pipe);
				}

			IT->quit();
			IT->wait_quit(HERE);
		}

		WHILE(output ::= iddedup_pipe.get_some(HERE)) {
			FOR(output)
			{
				IF(parser_pipes[parser_round % ##parser_pipes]->full())
					parser_pipes[parser_round % ##parser_pipes]->get_some(HERE);
				pass_along_dedupler_to_preparser(IT, *parser_pipes[parser_round++ % ##parser_pipes]);
			}
		}
		iddedup_pipe.quit();

		FOR(parser_pipes)
		{
			WHILE(IT->get_some(HERE)) { ; }
			IT->quit();
		}

		iddedup_pipe.wait_quit(HERE);
		FOR(parser_pipes) IT->wait_quit(HERE);
	}

	parse_string(str: tok::Token #&, alloc: std::temp::Alloc &) CHAR#[#]
	{
		ASSERT(str.Type == :String);
		contents ::= str.contents();
		SWITCH(t ::= str.SType.String)
		{
		:StringQuote, :StringApostrophe:
			contents := contents[FROM 1 UNTIL ##contents-1];
		DEFAULT:
			term::error(HERE, "unhandled string type: ", std::str::enum(t));
		}

		buffer ::= <CHAR *>(std::heap::alloc.alloc_raw_region(##contents, 16))[];

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

		WHILE(token.Type == :AuxKeyword
			&& token.SType.AuxKeyword == :include)
		{
			path: rlc::tok::Token (BARE);
			IF(!tokeniser.parse_next(&path))
				term::error(tokeniser.at(), "expected path after INCLUDE.");

			IF(path.Type != :String)
				term::error(path.at(), "unexpected token after include ", std::str::c(<CHAR #*>(path.Type)[]));
			IF(path.SType.String != :StringApostrophe && path.SType.String != :StringQuote)
				term::error(path.at(), "invalid string type for includes");

			added: ?& := (includes += path);

			IF!(tokeniser.parse_next(&token))
				= NULL;
		}
		= :a(token);
	}

	::detail EXTERN getenv(CHAR #*) CHAR #*;
}