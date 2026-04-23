INCLUDE "srcloader.rl"
INCLUDE "../includes.rl"
INCLUDE "codetoker.rl"
INCLUDE "codeparser.rl"
INCLUDE "iddedupler.rl"


::rlc::compiler Stage1
{
	Build: compiler::Build \;

	{build: compiler::Build \}:
		Build := build,
		Loader(build->BasePath, >build->IncludePaths!),
		TokersAlive := ##Tokenisers
	{
		Loader.Constant.HookCtx           := &THIS;
		Loader.Constant.PostJobHook       := on_file_loaded;
		Loader.Constant.IdleHook          := on_loader_idle;
		Loader.Constant.QuitHook          := on_loader_quit;
		FOR(Tokenisers) IT.Constant.PostJobHook := on_file_tokenised;
		FOR(Tokenisers) IT.Constant.QuitHook    := on_tokeniser_quit;
		FOR(Tokenisers) IT.Constant.HookCtx     := &THIS;
		IdDedupler.Constant.PostJobHook      := on_file_iddeduped;
		IdDedupler.Constant.HookCtx          := &THIS;
		IdDedupler.Constant.QuitHook         := on_iddedup_quit;
	}

	{&&} (BARE) { DIE; }
	{#&} (BARE) { DIE; }

	launch_workers() VOID
	{
		IF!(Build->SINGLE_THREADED)
		{
			Parser.MasterLocal.Threaded := TRUE;
			IdDedupler.MasterLocal.Threaded := TRUE;
			FOR(Tokenisers) IT.MasterLocal.Threaded := TRUE;
			Loader.MasterLocal.Threaded := TRUE;

			IdDedupler.launch_worker();
			FOR(Tokenisers) IT.launch_worker();
			Loader.launch_worker();
			//Parser.launch_worker(); // we run the parser pipe in the main thread, which saves us the sleep/notify and additional thread creation.
		}
	}

	run(files: std::Str#[#]) VOID
	{
		start_time ::= NOW;
			FOR(files) Loader.issue(HERE, :relative(Build->BasePath, IT!, NULL));
			Loader.flush(); // we are only allowed to flush once from the main thread.
			IF!(Build->SINGLE_THREADED)
				Parser.run_worker();
		post_process_start ::= NOW;
			Parser.Worker.preparse2();
		end_time ::= NOW;

		IF(Build->Type == :checkSyntax)
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

			phase_1_time ::= post_process_start - start_time;
			post_time ::= end_time - post_process_start;
			lines_per_second ::= (GIGA * lines) / (phase_1_time + post_time);
			lines_per_second_1 ::= (GIGA * lines) / (phase_1_time);
			lines_per_second_2 ::= (GIGA * lines) / (post_time);
			target: U8 := MEGA; // million lines per second.
			budget_1 ::= (10000 * target) / lines_per_second_1;
			budget_2 ::= (10000 * target) / lines_per_second_2;

			term::info(NULL, "Phase 1: ", std::io::format::dec(##src::fileNames), "F (", std::io::format::dec(lines), "L, ", std::io::format::dec(size), "B) in ",
				std::io::format::dec(phase_1_time / 1000000), ".", std::io::format::dec_x((phase_1_time % 1000000) / 1000, 3),
				"+", std::io::format::dec(post_time / 1000000), ".", std::io::format::dec_x((post_time % 1000000) / 1000, 3), "ms. ",
				std::io::format::dec(##ident::strings), "|",
				std::io::format::dec(ident::GlobalDeclCount), " ids"
				", ",
				std::io::format::dec_x(Loader.SlaveLocal.Processing / (CPU_TICK_RATE/MEGA), :Pad(5)), "µs load, ",
				std::io::format::dec_x(Tokenisers[0].SlaveLocal.Processing / (CPU_TICK_RATE/MEGA), :Pad(5)),
				"+",std::io::format::dec_x(Tokenisers[1].SlaveLocal.Processing / (CPU_TICK_RATE/MEGA), :Pad(5)),
				"+",std::io::format::dec_x(Tokenisers[2].SlaveLocal.Processing / (CPU_TICK_RATE/MEGA), :Pad(5)),
				"µs tok, ",
				std::io::format::dec_x(IdDedupler.SlaveLocal.Processing / (CPU_TICK_RATE/MEGA), :Pad(5)), "µs dedup, ",
				std::io::format::dec_x(Parser.SlaveLocal.Processing / (CPU_TICK_RATE/MEGA), :Pad(5)), "µs parse",
				" // ",
				std::io::format::dec((end_time - start_time) / size), ".", std::io::format::dec_x((((end_time - start_time) % size) * 100) / size, 2), "ns/B, ",
				std::io::format::dec((lines_per_second + 500) / MEGA), ".", std::io::format::dec_x(((lines_per_second + 500) % MEGA) / 1000, 3), "ML/s, ",
				std::io::format::dec(budget_1 / 100), ".", std::io::format::dec_x(budget_1 % 100, 2), "%+",
				std::io::format::dec(budget_2 / 100), ".", std::io::format::dec_x(budget_2 % 100, 2), "% of budget"
				);
		}
	}


	Loader: @(CACHELINE) [SrcLoader; #256]PipelineSetup;
		TokPipeNext: INT;
		STATIC on_loader_quit(ctx: VOID*) VOID
		{
			this ::= <THIS *>(ctx);
			FOR(this->Tokenisers) IT.quit();
		}
		STATIC on_loader_idle(ctx: VOID*) VOID
		{
			this ::= <THIS *>(ctx);

			this->Loader.sync(); // sync MASTERLOCAL state.
			IF(this->Loader.pending())
				this->Loader.flush();
			ELSE // IF(!Loader.pending_slave())
				this->Loader.quit();
		}
		STATIC on_file_loaded(ctx: VOID*, result: SrcLoader::Output &) VOID
		{
			<THIS *>(ctx)->on_file_loaded_impl(result);
		}
		on_file_loaded_impl(result: SrcLoader::Output &) VOID --
		{
			// Problem: each job produces more jobs, but we have only a finite job queue. The number of jobs can temporarily peak excessively. We could change the file loader to a custom solution to fix this.

			IF!(result) RETURN;

			//term::info(NULL, "Loaded file ", std::io::format::dec(result!.File), " ", result!.Name);

			STATIC includes: tok::Token -std::Vec := :reserve(2048);
			STATIC fileNames: std::temp::Alloc := :custom(1<<16, 1 << 12);
			includes.clear_reuse();
			fileNames.clear_and_optimise(1024);

			f ::= result!.File;
			contents ::= result!.Content;

			// Parse includes.
			tokeniser: rlc::tok::Tokeniser(f, contents);
			first_token ::= parse_includes(includes, tokeniser);

			basefile: os::fs::FilePath := result!.Name;

			// Do not load includes if we are to only check the syntax of the input files.
			IF(Build->Type != :checkSyntax)
			{
				// Queue all includes for the loader.
				FOR(includes!)
				{
					ASSERT(IT.Type == :String);
					Loader.issue(HERE,
						IT.SType.String == :StringQuote
						?? include::IncludeType::relative
						: include::IncludeType::global,
						basefile.Directory, parse_string(IT, fileNames), IT.at());
				}
			}

			IF!(first_token) RETURN;

			// Issue the rest of the file to a tokeniser thread.
			Tokenisers[TokPipeNext++ % ##Tokenisers].issue_flush(HERE, &&tokeniser, *first_token, f);
		}

	Tokenisers: @(CACHELINE)  [CodeTokeniser; #32]PipelineSetup[3];
		STATIC on_file_tokenised(ctx: VOID*, result: CodeTokeniser::Output &) VOID
			{ <THIS *>(ctx)->pass_along_toker_to_dedupler(result); }
		TokersAlive: @(CACHELINE) INT.;
		STATIC on_tokeniser_quit(ctx: VOID *) VOID
			{ <THIS *>(ctx)->on_tokeniser_quit_impl(); }
		on_tokeniser_quit_impl() VOID --
		{
			IF!( TokersAlive += :?(-1) ) IdDedupler.quit();
		}

	IdDedupler: @(CACHELINE) [compiler::IdDeDupler; #32]PipelineSetup;
		STATIC on_file_iddeduped(ctx: VOID*, result: IdDeDupler::Output &) VOID
			{ <THIS *>(ctx)->on_file_iddeduped_impl(result); }
		on_file_iddeduped_impl(result: IdDeDupler::Output &) VOID --
		{
			pass_along_dedupler_to_preparser(result);
			IF(Build->TRACK_FILE_IDSETS)
				term::info(NULL, std::io::format::dec(result.LocalIds), " identifiers in ", src::fileNames[:ok(result.File)]);
		}
		STATIC on_iddedup_quit(ctx: VOID*) VOID
			{ <THIS *>(ctx)->on_iddedup_quit_impl(); }
		on_iddedup_quit_impl() VOID --
			{ Parser.quit(); }
	Parser: @(CACHELINE) [CodeParser; #32]PipelineSetup;


	DeduplerMutex: BOOL.;
	pass_along_toker_to_dedupler(
		out: CodeTokeniser::Output #&) VOID
	{
		WHILE(DeduplerMutex :=: :<(TRUE)) PAUSE;

		next_input ::= IdDedupler.next_input(HERE);
		next_input->Tokens := out.Tokens;
		next_input->File := out.File;
		IdDedupler.issue_flush_prepared();

		DeduplerMutex := :>(FALSE);
	}

	pass_along_dedupler_to_preparser(
		out: IdDeDupler::Output #&) VOID
	{
		next_input ::= Parser.next_input(HERE);

		next_input->File := out.File;
		next_input->LocalIds := out.LocalIds;
		next_input->Tokens := out.Tokens;

		Parser.issue_flush_prepared();
	}

	STATIC parse_string(str: tok::Token #&, alloc: std::temp::Alloc &) CHAR#[#]
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

	STATIC parse_includes(
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
}