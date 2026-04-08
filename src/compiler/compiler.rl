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



		[X] Phase 1: load all files, tokenise, assemble global scope as quickly as possible.
		[X] load ---> [X] tokenise ---> [X] ident dedup ----> [X] preparse ------------>
		                                                                   global scope

		[/] Phase 2: finish populating the global scope, resolving all references.
		------------------------> [ ] preparse2 ---> [ ] body-parse ------------>
		       global scope                                             IR0
		                                                            (Templated,
		                                                         semi-type-checked)

		[ ] Phase 3: generate code.
		                          ---> optimiser---
		                         /                 \
		---> [ ] instantiator --<--> [ ] optimiser ->--> [ ] codegen ----> [ ] link ---->
		 IR0                    IR1                 IR2              obj0           obj1
		(Templated,        (Instantiated,         (=IR1?)
		semi-type-checked) type-checked)

		IR0 should probably be a mix of TRASM and RASM. and IR1 should be RASM, basically.

		And TRASM is basically just RASM with placeholders for immediates or operations.
		RASM should be as semantically rich as possible, so that no intent gets lost and would have to be regained later. For machine-specific optimisation of the code (such as instruction scheduling and register usage), we should do a final assembly-level optimisation pass after having optimised on the high level RASM already.
		RASM should integrate as neatly into the language as possible, by exposing lots of intrinsics / builtin operators (such as POPCNT, BSWAP, etc.).
		A register allocation pass should be mandatory for codegen, so that we never output GCC -O0 tier code that rapes the stack. Constant expression execution should also be mandatory, as well as inlining of inline functions. Especially initialisation of static data tables etc. Beyond that, all other optimisations should be optional.

		We should not need inline assembly. We might need to be able to link to ELF.o files, though, as a way to link to C/ASM stubs for things like syscalls and the general runtime.

		We probably want to also have a tool that converts the IR2 to C or something, so that we can have portable builds that are easy to bootstrap elsewhere (hopefully). Then we can either ship the C-converted IR2, or the IR2->C converter and the IR2.

		We do not need debugging ability. We need to have a C printer for reference, though, for finding bugs in our separate backends. But actually, C is annoying. We can add it once the x86 backend breaks. More useful would be a way to interpret RASM directly, maybe from C. Then we can run RASM programs everywhere in interpreted mode, and build up our strengths from there, so that we can later add direct debugging to RASM and also add it as ground truth. Then we can emulate, or compile RASM, not wasting effort on other technology.

		- [X] Phase 1
			- [X] loader
			- [X] tokeniser
			- [X] Identifier deduplicator (global & file-local).
			- [X] globalscope preparser
			- [/] preparse2: class members, etc. -- might move this to phase 1.
		- [/] Phase 2
			- [ ] return type & field type resolution: at least for untemplated things.
			- [ ] body-parse / post-parse: types, function bodies, expressions, etc.
				- [ ] typechecking
				- [ ] IR0 codegen (TRASM?)
		- [ ] Phase 3
			- [ ] instantiator
			- [ ] optimiser (not essential for now)
			- [ ] x86 codegen
				- [ ] link post-pass & ELF production
				- [ ] optimising codegen
			- [ ] Wasm codegen (no link pass needed, probably, although we need to provide a runtime like the heap. But this can also be done by supplying platform-specific code directly. The only annoying thing would be that we would need to be able to call some WASM builtins like __builtin_wasm_memory_size() / __builtin_wasm_memory_grow(). Although we could also have a builtin that just inserts an opcode. Then we can skip having to be able to read WASM files.)
				- [ ] optimising codegen


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
		       <--- [/] scope trees + IR0 --------------------------------------

		       [X] merge scopes
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

		// We declare the pipes globally so that we can access them from the post-job hooks, letting them communicate.
		STATIC loader_pipe: [SrcLoader; #256]PipelineSetup (NOINIT);
			STATIC on_loader_quit(VOID*) VOID { FOR(tok_pipes) IT.quit(); }
			STATIC on_file_loaded(ctx: VOID*, result: SrcLoader::Output &) VOID
			{
				IF!(result)
				{
					IF!(loader_pipe.pending_slave()) loader_pipe.quit();
					RETURN;
				}

				STATIC includes: tok::Token -std::Vec := :reserve(2048);
				STATIC fileNames: std::temp::Alloc := :custom(1<<16, 1 << 12);
				includes.clear_reuse();

				f ::= result!.File;
				contents ::= result!.Content;

				// Parse includes.
				tokeniser: rlc::tok::Tokeniser(f, contents);
				first_token ::= compiler::parse_includes(includes, tokeniser);

				basefile: os::fs::FilePath := result!.Name;

				build ::= <Build *>(ctx);
				// Do not load includes if we are to only check the syntax of the input files.
				IF(build->Type != :checkSyntax)
				{
					// Queue all includes for the loader.
					FOR(includes!)
					{
						ASSERT(IT.Type == :String);
						loader_pipe.issue(HERE,
							IT.SType.String == :StringQuote
							?? include::IncludeType::relative
							: include::IncludeType::global,
							basefile.Directory, parse_string(IT, fileNames), IT.at());
					}
					loader_pipe.flush();
				}

				IF!(first_token)
				{
					IF!(loader_pipe.pending_slave()) loader_pipe.quit();
					RETURN;
				}

				// Issue the rest of the file to a tokeniser thread.
				STATIC tok_pipe_next: INT := 0;
				tok_pipes[tok_pipe_next++ % ##tok_pipes].issue_flush(HERE, &&tokeniser, *first_token, f);
			}

		STATIC tok_pipes: [CodeTokeniser; #16]PipelineSetup[2];
			STATIC on_file_tokenised(VOID*, result: CodeTokeniser::Output &) VOID
			{
				STATIC mutex: BOOL. := FALSE;

					WHILE(mutex :=: :<(TRUE)) {;}
				pass_along_toker_to_dedupler(result, iddedup_pipe);
					mutex := :>(FALSE);
			}
			STATIC on_tokeniser_quit(VOID *) VOID
			{
				STATIC alive: INT. := ##tok_pipes;
				IF!( alive += :?(-1)) iddedup_pipe.quit();
			}

		STATIC iddedup_pipe: [IdDeDupler; #16]PipelineSetup;
			STATIC on_file_iddeduped(VOID*, result: IdDeDupler::Output &) VOID
				{ pass_along_dedupler_to_preparser(result, parser_pipe); }
			STATIC on_iddedup_quit(VOID*) VOID
				{ parser_pipe.quit(); }
		STATIC parser_pipe: [CodeParser; #16]PipelineSetup;

		(//
			Compiles the given input files according to the specified build flags.
		/)
		compile(
			files: std::Str#[#],
			build: Build
		) VOID
		{
			loader_pipe.{ build.BasePath, >build.IncludePaths! };

			loader_pipe.Constant.HookCtx           := &build;
			loader_pipe.Constant.PostJobHook       := on_file_loaded;
			loader_pipe.Constant.QuitHook          := on_loader_quit;
			FOR(tok_pipes) IT.Constant.PostJobHook := on_file_tokenised;
			FOR(tok_pipes) IT.Constant.QuitHook    := on_tokeniser_quit;
			iddedup_pipe.Constant.PostJobHook      := on_file_iddeduped;
			iddedup_pipe.Constant.QuitHook         := on_iddedup_quit;

			IF!(build.SINGLE_THREADED)
			{
				loader_pipe.launch_worker();
				FOR(tok_pipes) IT.launch_worker();
				iddedup_pipe.launch_worker();
				//parser_pipe.launch_worker();
			}

			start_time ::= NOW;
				FOR(files) loader_pipe.issue(HERE, :relative(build.BasePath, IT!, NULL));
				loader_pipe.flush(); // we are only allowed to flush once from the main thread.
				IF!(build.SINGLE_THREADED)
					parser_pipe.run_worker();
			end_time ::= NOW;

			IF(build.Type == :checkSyntax)
				RETURN;

			{
				size ::= 0;
				lines ::= 0;
				FOR(src::fileContents!)
				{
					IF(##IT) lines += IT[][##IT-1] != '\n';
					size += ##IT;
					FOR(IT) lines += IT == '\n';
				}

				lines_per_second ::= (GIGA * lines) / (end_time - start_time);
				target: U8 := 1000000;
				budget ::= (10000 * target) / lines_per_second;

				term::info(NULL, "Phase 1: ", std::io::format::dec(##src::fileNames), "F (", std::io::format::dec(lines), "L, ", std::io::format::dec(size), "B) in ", std::io::format::dec((end_time - start_time) / 1000000), ".", std::io::format::dec_x(((end_time - start_time) % 1000000) / 1000, 3), "ms. ", std::io::format::dec(##ident::strings), " ids"
					", ",
					std::io::format::dec_x(loader_pipe.SlaveLocal.Processing / (CPU_TICK_RATE/MEGA), :Pad(5)), "µs load, ",
					std::io::format::dec_x(tok_pipes[0].SlaveLocal.Processing / (CPU_TICK_RATE/MEGA), :Pad(5)), "µs+",
					std::io::format::dec_x(tok_pipes[1].SlaveLocal.Processing / (CPU_TICK_RATE/MEGA), :Pad(5)), "µs tok, ",
					std::io::format::dec_x(iddedup_pipe.SlaveLocal.Processing / (CPU_TICK_RATE/MEGA), :Pad(5)), "µs dedup, ",
					std::io::format::dec_x(parser_pipe.SlaveLocal.Processing / (CPU_TICK_RATE/MEGA), :Pad(5)), "µs preparse",
					" // ",
					std::io::format::dec((end_time - start_time) / size), ".", std::io::format::dec_x((((end_time - start_time) % size) * 100) / size, 2), "ns/B, ",
					std::io::format::dec((lines_per_second + 500) / MEGA), ".", std::io::format::dec_x(((lines_per_second + 500) % MEGA) / 1000, 3), "ML/s, ",
					std::io::format::dec(budget / 100), ".", std::io::format::dec_x(budget % 100, 2), "% of budget"
					);
			}

			(/ TODO:
				- [X] factor out include parsing.
				- [X] resolve include paths.
				- [X] tokenise included files.
				- [X] debug tempalloc.
				- [X] pre-parse & dedup identifiers
				- [X] assemble scope tree
				- [/] preparse all members properly
					- [X] classes, etc.
					- [X] functions
					- [X] operators
					- [ ] intrinsics
				- [X] write AST merger? Actually just let the parser write into the global AST (rather: scope tree) directly.
				- [ ] Check whether making tokeniser process in a loop produces a speedup.
				- [ ] Fully post-process tokens (strings, numbers)?
				- [ ] write post-parser
					- [ ] resolve all type names, field types, typedefs, return types, and inheritances, until all types outside of function bodies are resolved.
					- [ ] Deduplicate type names, similar to the identifiers?
						-- we need to think about the concrete type-checking algorithm and its needs. Also, types do not necessarily have to be encoded in data, if they only belong to temporary values that are immediately consumed. In such cases, the type information can be entirely contextual.
							- we also need to think about the execution model of the type checker & instantiator.
					- [ ] LATER: think about how to handle auto return types.
				- [ ] resolver? -- no longer needed.
				- [ ] IR -- this is part of the parser already somewhat.
				- [ ] type check & instantiator
				- [ ] code gen /)

			(/ Thoughts / Problems:
				- What is the best way to parse? After having all global scope entries, we can start parsing everything, but we cannot yet reference static members, etc..
					- We could use 2 preparse steps, where variable types and similar references to global things only get resolved after the second pass. The second pass would create all types and all functions.
					- Or we merge both into the initial preparse, so that we do not have to touch the tokens twice on potentially different cores. Then we have all classes and all functions etc. already populated in the preparser, and only need to post-parse arguments, types, and bodies/expressions.
					- Note that we still need to resolve types out of order if we want to be able to refer to later types from earlier types and embed them. We basically need one full resolution pass, and then another pass that tallies up struct sizes and checks for recursive structs.
						- Only after this pass should we parse function bodies, etc., so that we can directly generate code as we parse, without an immediate AST that gets later completed.
						- We want to generate some IR code already during the parsing, even before fully instantiating all types.
						- We also want to know whether certain operations are nops before generating code? Although we also have to be able to hotpatch those when templating, anyway.
			/)


			
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
		next_input ::= pipe.next_input(HERE);
		next_input->Tokens := out.Tokens;
		next_input->File := out.File;
		pipe.issue_flush_prepared();
	}

	pass_along_dedupler_to_preparser(
		out: IdDeDupler::Output &,
		pipe: [CodeParser]Pipeline &) VOID
	{
		next_input ::= pipe.next_input(HERE);

		next_input->File := out.File;
		next_input->LocalIds := out.LocalIds;
		next_input->Tokens := out.Tokens;

		pipe.issue_flush_prepared();
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
		STATIC tokens: tok::FileTokens;
		tokens.clear_reuse();
		tokens.reserve(2);

		view ::= tokens.view();
		IF!(tokeniser.parse_next(&view))
			= NULL;

		hots ::= tokens.Hots![];
		payloads ::= tokens.Payloads![];
		positions ::= tokens.Positions![];

		WHILE(hots->Type == :AuxKeyword
			&& hots->SType.AuxKeyword == :include)
		{
			IF(!tokeniser.parse_next(&view))
				term::error(tokeniser.at(), "expected path after INCLUDE.");

			path: tok::Token (BARE);
			path.Type := hots[1].Type;
			path.SType.{ hots[1].SType };
			path.Payload.{payloads[1]};
			path.Position := positions[1].Pos;
			path.Length := positions[1].Length;

			IF(hots[1].Type != :String)
				term::error(path.at(), "unexpected token after include ", std::str::c(<CHAR #*>(path.Type)[]));
			IF(hots[1].SType.String != :StringApostrophe && hots[1].SType.String != :StringQuote)
				term::error(path.at(), "invalid string type for includes");


			added: ?& := (includes += path);
			view := tokens.view();

			IF!(tokeniser.parse_next(&view))
				= NULL;
		}

		first_token: tok::Token (BARE);
		first_token.Type := hots->Type;
		first_token.SType.{ hots->SType };
		first_token.Payload.{*payloads};
		first_token.Position := positions->Pos;
		first_token.Length := positions->Length;
		= :a(first_token);
	}

	::detail EXTERN getenv(CHAR #*) CHAR #*;
}