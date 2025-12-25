::rlc::compiler [Job] Pipeline
{
	// shared constant state.
	State: Job *;

	Inputs: Job::Input+[#];
	Outputs: Job::Output+[#];

	// caller-local bookkeeping data.
	LocalIssued: @(CACHELINE) U4;
	LocalFlushed: U4;
	SeenProcessed: U4;
	Consumed: U4;
	Threaded: BOOL;

	// caller writes, worker reads.
	Issued: @(CACHELINE) U4.;
	// caller reads, worker writes.
	Processed: @(CACHELINE) U4.;
	// caller writes, worker reads.
	Quit: @(CACHELINE) BOOL.;

	{#&} (BARE) { DIE; }
	{&&} (BARE) { DIE; }

	{inputs: Job::Input+[#], outputs: Job::Output+[#], state: Job *}:
		State := state,

		Inputs := inputs,
		Outputs := outputs,

		Issued := 0,
		Processed := 0,
		Quit := FALSE;

	DESTRUCTOR { Quit := :>(TRUE); }

	worker_thread() VOID
	{
		processed ::= Processed(:?);

		WHILE(!Quit(:<))
		{
			issued ::= Issued(:<);
			IF(issued == processed)
				CONTINUE;

			WHILE(processed != issued)
			{
				State->handle_job(
					Inputs[processed % ##Inputs],
					&Outputs[processed % ##Outputs]);
				++processed;

				Processed := :>(processed);
			}
		}
	}

	[Args...]issue(input: Args!&&...) VOID --
	{
		Inputs[LocalIssued++ % ##Inputs].{<Args!&&>(input)...};
	}

	quit() VOID -- { Quit := :>(TRUE); }

	// Sends pending work to the worker. This also gets called automatically.
	flush() VOID -- {
		Issued := :>(LocalIssued);
		oldFlushed ::= LocalFlushed;
		LocalFlushed := LocalIssued;

		IF!(Threaded)
		{
			end ::= LocalFlushed;
			FOR(i ::= oldFlushed; i < end; i++)
				State->handle_job(
					Inputs[i % ##Inputs],
					&Outputs[i % ##Outputs]);
			Processed := :>(end);
		}
	}

	# pending() BOOL -- := LocalIssued != SeenProcessed;

	get_some() Job::Output+[#]
	{
		IF(!pending())
			= NULL;

		WHILE(Consumed == SeenProcessed)
		{
			IF(LocalFlushed == SeenProcessed)
				flush();

			SeenProcessed := Processed( :< );
		}

		start ::= Consumed % ##Outputs;
		end ::= SeenProcessed % ##Outputs;
		IF(end > start)
		{
			Consumed := SeenProcessed;
			= Outputs[FROM start UNTIL end];
		} ELSE
		{
			pre_wrap ::= Outputs[FROM start];
			Consumed += ##pre_wrap;
			= pre_wrap;
		}
	}
}