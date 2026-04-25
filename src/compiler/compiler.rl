INCLUDE 'std/string'
INCLUDE 'std/vector'
INCLUDE 'std/optional'
INCLUDE 'std/sync/race'

INCLUDE "1/stage.rl"
INCLUDE "2/stage.rl"

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

	Stats { size: U4; lines: U4; }

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
		TRACK_FILE_IDSETS: BOOL;

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

		// b: Build := :withOutput("test.exe", :executable)
		// (:withOutput, "test.exe", :executable)

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
			TRACK_FILE_IDSETS := std::str::eq(std::str::c(detail::getenv("RLC_IDS"!)[]), "1");

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



		~ 13.5 % of the budget, or 7.4M LOC/s
		-> output stuff that we skip over.
		~ 15 % of the budget, or 6.6M LOC/s... we want to get back to >7M.
		-> central pool of namespaces and member scopes
		~ 15 % of the budget, or 6.6M LOC/s...
		[X] Phase 1: load all files, tokenise, assemble global scope as quickly as possible.
		[X] load ---> [X] tokenise ---> [X] ident dedup ----> [X] preparse ------------>
		                                                                   global scope

		[/] Phase 2: finish populating the global scope, resolving all references.
		------------------------> [/] preparse2 ---> [ ] body-parse ------------>
		       global scope                                             IR0
		                                                            (Templated,
		                                                         semi-type-checked)

			~ 4.5 % of the budget, or 30M LOC/s
			-> allocator reuse, etc.
			~ 1.1 % of the budget, or 90M LOC/s
			-> Rework to queues instead of AST walking.
			~ 0.9 % of the budget, or 110M LOC/s
			-> Prefetching
			~ 0.82 % of the budget, or 120M LOC/s (33% speed increase)
			-> Condensed queues
			~ 0.9 % of the budget, or 110M LOC/s
			-> Prefetching the queue (more complex lookup pattern confused the HW prefetcher)
			~ 0.82% of the budget, or 120M LOC/s
			-> Ignoring queue lookups (doing less work)
			~ 0.9 % of the budget, or 110M LOC/s (????)
			-> central pool of namespaces and member scopes (unrelated to this)
			~ 0.76 % of the budget, or 130M LOC/s (????)

			[/] preparse2:
			           [X] type+code                 [ ] res.type+code
			[X] types parser ----> [ ] type/symbol resolver ---> [ ] IR0 generator? (TRASM/??)


			[ ] body-parse:
			-------------> expression typechecker ----------> ????????
			fully typed      & type resolver         IR0 +
			global scope                         instantiation
			 + bodies                              requests?

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
			Having a RASM -> C converter vs. a RASM interpreter vs. RASM -> assembly converter does not make that much of a difference. Though I guess we can definitely skip the C source printing step. Having a portable RASM interpreter would allow us to run code everywhere without having an actual compiler backend. This could be useful for browser apps for example. And this could be the reference against which we can check native codegen backends. And we can verify the interpeter against the bootstrap compiler. We can then ship a RASM of the compiler and the interpreter and already have a fully ported compiler.

			And yeah, we definitely want to build our own foundation on top of RASM, and not on top of some retarded platform-specific format like ELF+DWARF and whatever other OSes are using. We want to have a debugger that integrates on a language level, not on a machine-code level.

			Also, having RASM instead of machine code for debugging also allows us to check for thread safety and memory model stuff, and initialisation, page faults, and all those things. We can even simulate cache behaviour and generate performance profile data based on that. For that, we need a very mature RASM interpreter.

			We can then also set the CPU performance profile in the interpreter to help the optimiser (latency & throughput of instructions, issue ports, branch miss penalties, memory latencies, line fill buffers, etc.).

		- [X] Phase 1
			- [X] loader
			- [X] tokeniser
			- [X] Identifier deduplicator (global & file-local).
			- [X] globalscope preparser
			- [X] preparse2: class members, etc. -- might move this to phase 1.
			- [X] post-pass:
				- [X] compress namespace scopes (globalIds)
				- [X] bake namespace-relative lookups. (globalDeclIds)
				- [X] compress member scopes (fileIds -> fileDeclIds)
				- [X] bake member-scope-relative lookups. (fileDeclIds)
		- [/] Phase 2
			- [ ] return type & field type resolution: at least for untemplated things.
			- [ ] body-parse / post-parse: types, function bodies, expressions, etc.
				- [ ] typechecking
				- [ ] IR0 codegen (TRASM?)
		- [ ] Phase 3
			- [ ] instantiator (TRASM -> RASM, full resolution)
			- [ ] optimiser (not essential for now)
			- [ ] RASM codegen & RASM interpreter
		- [ ] Phase 4
			- [ ] x86 codegen -- we could also have a pseudo-x86 IR stage if that helps with anything, and then generate actual x86 from that. Then we do not have to optimise on actual x86 instruction encodings.
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

		(//
			Compiles the given input files according to the specified build flags.
		/)
		compile(
			files: std::Str#[#],
			build: Build
		) VOID
		{
			stats: Stats;
			{
				stage1: stage1::Stage1 (&build);
				stage1.launch_workers();
				stats := stage1.run(files);
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
				- [X] namespace scope merging for O(1) relative lookups
				- [X] member scope merging for O(1) relative lookups
				- [X] Check whether making tokeniser process in a loop produces a speedup.
				- [ ] Fully post-process tokens (strings, numbers)?
				- [/] write post-parser
					- [/] resolve all type names, field types, typedefs, return types, and inheritances, until all types outside of function bodies are resolved.
					- [ ] Deduplicate type names, similar to the identifiers?
						-- we need to think about the concrete type-checking algorithm and its needs. Also, types do not necessarily have to be encoded in data, if they only belong to temporary values that are immediately consumed. In such cases, the type information can be entirely contextual.
							- we also need to think about the execution model of the type checker & instantiator.
					- [ ] LATER: think about how to handle auto return types.
				- [ ] resolver? -- This is now simply an operation in the IR bytecode.
				- [ ] IR -- this is part of the parser already somewhat.
				- [ ] type check & instantiator
				- [ ] code gen /)

			(/ Thoughts / Problems:
				- What is the best way to parse? After having all global scope entries, we can start parsing everything, but we cannot yet reference static members, etc..
					- We could use 2 preparse steps, where variable types and similar references to global things only get resolved after the second pass. The second pass would create all types and all functions.
					- [X] Or we merge both into the initial preparse, so that we do not have to touch the tokens twice on potentially different cores. Then we have all classes and all functions etc. already populated in the preparser, and only need to post-parse arguments, types, and bodies/expressions.
					- Note that we still need to resolve types out of order if we want to be able to refer to later types from earlier types and embed them. We basically need one full symbol resolution pass, and then another pass that tallies up struct sizes and checks for recursive structs.
						- Only after this pass should we parse function bodies, etc., so that we can directly generate code as we parse, without an immediate AST that gets later completed.
						- We want to generate some IR code already during the parsing, even before fully instantiating all types.
						- We also want to know whether certain operations are nops before generating code? Although we also have to be able to hotpatch those when templating, anyway.
			/)


			
			/// Parse included files.

			IF(build.Type == :createAST)
				RETURN;

			IF(1)
			{
				stage2: Stage2 (&build);
				//stage2.launch_workers();
				stage2.run(stats);
			}

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

	::detail EXTERN getenv(CHAR #*) CHAR #*;
}