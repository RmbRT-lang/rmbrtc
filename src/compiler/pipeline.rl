::threading threads_spawned : U8. := 0;
::rlc::compiler [Job] Pipeline
{
	// shared constant state.
	ConstantR {
		State: Job *;

		Inputs: Job::Input+[#];
		Outputs: Job::Output+[#];

		HookCtx: VOID *;
		PostJobHook: ((VOID *, Job::Output+ &) VOID) *;
		QuitHook: ((VOID*) VOID) *;
	}

	// caller-local bookkeeping data.
	MasterLocalR {
		Issued: @(CACHELINE) U4;
		Flushed: U4;
		SeenProcessed: U4;
		Consumed: U4;
		Threaded: BOOL;
	}

	MasterR {
		// caller writes, worker reads.
		Issued: @(CACHELINE) U4.;
	}


	SlaveR {
		// caller reads, worker writes.
		Processed: @(CACHELINE) U4.;
	}
	SlaveLocalR {
		Waiting: U8;
		Processing: U8;
	}

	SharedR {
		// caller writes, worker reads.
		Quit: @(CACHELINE) BOOL.;
		{}: Quit := TRUE;
	}
	Constant: ConstantR;
	MasterLocal: MasterLocalR;
	Master: MasterR;
	Slave: SlaveR;
	SlaveLocal: SlaveLocalR;
	Shared: SharedR;

	{#&} (BARE) { DIE; }
	{&&} (BARE) { DIE; }

	{inputs: Job::Input+[#], outputs: Job::Output+[#], state: Job *}:
		Constant (state, inputs, outputs, NULL, NULL, NULL)
	{
		ASSERT(##Constant.Inputs == ##Constant.Outputs);
	}

	DESTRUCTOR { Shared.Quit := :>(TRUE); }


	PUBLIC run_worker() VOID {
		MasterLocal.Threaded := TRUE;
		worker_thread();
	}

	PRIVATE worker_thread() VOID
	{
		Master: MasterR # & := THIS.Master;
		Constant: ConstantR #& := THIS.Constant;
		Slave: SlaveR & := THIS.Slave;
		Shared: SharedR & := THIS.Shared;

		// Assuming 8 cores, and 2 threads per core. Ideally, we could also get rid of the two tokeniser threads.
		STATIC thread_masks: INT[?](
			0b00000001, // loader
			0b00000100, // tokeniser 0
			0b00001000, // tokeniser 1
			0b00010000, // dedupler
			0b01000000  // parser
		);
		thread_id ::= (threading::threads_spawned += :?(<U8>(1))) - 1;
		IF(THREAD_COUNT >= 8)
		{
			cores ::= thread_masks[thread_id];
			__rl::set_thread_affinity(cores);
		}

		processed ::= Slave.Processed(:<);
		Shared.Quit := :>(FALSE);

			start_waiting ::= CPU_COUNTER;

		FOR(;;)
		{
			quit ::= Shared.Quit(:<);
			issued ::= Master.Issued(:<); // load this AFTER the quit, so that we know this is at least as recent. This way, if we receive the quit signal, we do not have to worry about not yet having received work that was issued before the quit signal.
			IF(issued == processed)
			{
				IF(quit) BREAK; // only ever heed the quit request after we finished all work.

				PAUSE;
				CONTINUE;
			}

				start_processing ::= CPU_COUNTER;
				end_waiting ::= start_processing;
				SlaveLocal.Waiting += end_waiting - start_waiting;

			WHILE(processed != issued)
			{
				output ::= &Constant.Outputs[processed % ##Constant.Outputs];
				Constant.State->handle_job(
					Constant.Inputs[processed % ##Constant.Inputs],
					output);
				++processed;

				Slave.Processed := :>(processed);

				IF(Constant.PostJobHook) Constant.PostJobHook(Constant.HookCtx, *output);
			}

				start_waiting := CPU_COUNTER;
				end_processing ::= start_waiting;
				SlaveLocal.Processing += end_processing - start_processing;
		}

		IF(Constant.QuitHook) Constant.QuitHook(Constant.HookCtx);
		Shared.Quit := :>(FALSE);
	}

	wait_launched() VOID --
	{
		tries: U4 := 0;
		start ::= NOW;
		WHILE(Shared.Quit(:<))
		{ IF!(++tries & 1023) { IF((NOW)-start > 100 * MEGA) DIE; } }
	}

	launch_worker() VOID^
	{
		MasterLocal.Threaded := TRUE;
		thread: VOID^(^worker_thread());
		wait_launched();
		= &&thread;
	}

	next_input(w: WHERE) Job::Input \
	{ // AS MASTER
		IF!(MasterLocal.Issued - MasterLocal.Consumed < ##Constant.Inputs)
			IF!(get_some(w)) term::error(w,
				"Cannot issue work for ", Job::name(), ": queue full and nothing flushed");

		= &Constant.Inputs[MasterLocal.Issued % ##Constant.Inputs];
	}

	[Args...]issue(w: WHERE, input: Args!&&...) VOID --
	{ // AS MASTER
		IF!(MasterLocal.Issued - MasterLocal.Consumed < ##Constant.Inputs)
			IF!(get_some(w)) term::error(w,
				"Cannot issue work for ", Job::name(), ": queue full and nothing flushed");

		Constant.Inputs[MasterLocal.Issued++ % ##Constant.Inputs].{<Args!&&>(input)...};
	}

	issue_prepared() VOID --
	{
		ASSERT(MasterLocal.Issued - MasterLocal.Consumed < ##Constant.Inputs);
		MasterLocal.Issued++;
	}

	issue_flush_prepared() VOID --
	{
		issue_prepared();
		flush();
	}

	quit() VOID -- { // AS MASTER
		Shared.Quit := :>(TRUE);
		IF!(MasterLocal.Threaded)
			IF(Constant.QuitHook) Constant.QuitHook(Constant.HookCtx);
	}
	wait_quit(at: WHERE) VOID --
	{ // AS MASTER
		IF!(MasterLocal.Threaded) RETURN;

		start ::= NOW;
		attempt ::= 0;
		WHILE(Shared.Quit(:<))
		{
			PAUSE;
			IF!(++attempt & 1023)
				IF((NOW) - start > 100 * MEGA)
					term::error(at, Job::name(), " thread is stuck!");
		}
	}

	/// Sends pending work to the worker. This also gets called automatically.
	flush() VOID -- { // AS MASTER
		Master.Issued := :>(MasterLocal.Issued);
		oldFlushed # ::= MasterLocal.Flushed;
		MasterLocal.Flushed := MasterLocal.Issued;

		IF!(MasterLocal.Threaded)
		{ // AS SLAVE
			end ::= MasterLocal.Flushed;
			start_cycle ::= CPU_COUNTER;
			FOR(i ::= oldFlushed; i < end; i++)
				Constant.State->handle_job(
					Constant.Inputs[i % ##Constant.Inputs],
					&Constant.Outputs[i % ##Constant.Outputs]);
			SlaveLocal.Processing += CPU_COUNTER - start_cycle;
			Slave.Processed := :>(end);

			IF(Constant.PostJobHook)
				FOR(i ::= oldFlushed; i < end; i++)
					Constant.PostJobHook(Constant.HookCtx, Constant.Outputs[i % ##Constant.Outputs]);
		}
	}

	[Args...]issue_flush(w: WHERE, input: Args!&&...) VOID --
	{
		THIS.[Args!...]issue(w, <Args!&&>(input)...);
		flush();
	}

	# full() BOOL := MasterLocal.Issued - MasterLocal.Consumed == ##Constant.Inputs;
	# pending() U4 -- := MasterLocal.Issued - MasterLocal.SeenProcessed;
	# pending_slave() U4 -- := Master.Issued(:?) - Slave.Processed(:?);

	try_get_some() Job::Output+[#]
	{ // AS MASTER

		= NULL; // somehow, using more fine-grained batching actually reduces speed for some reason.

		IF(!pending())
			= NULL;

		IF(MasterLocal.Consumed == MasterLocal.SeenProcessed)
		{
			IF(MasterLocal.Flushed != MasterLocal.Issued)
				flush();
			MasterLocal.SeenProcessed := Slave.Processed( :< );
		}
		IF(MasterLocal.Consumed == MasterLocal.SeenProcessed)
			= NULL;

		start ::= MasterLocal.Consumed % ##Constant.Outputs;
		end ::= MasterLocal.SeenProcessed % ##Constant.Outputs;

		ret: Job::Output+[#];
		IF(end > start)
			ret := Constant.Outputs[FROM start UNTIL end];
		ELSE
			ret := Constant.Outputs[FROM start];
		MasterLocal.Consumed += ##ret;
		= ret;
	}

	get_some(at: WHERE) Job::Output+[#]
	{ // AS MASTER
		IF(!pending())
			= NULL;

			{
		start: U8;
		attempt: U4 := 0;
		WHILE(MasterLocal.Consumed == MasterLocal.SeenProcessed)
		{
			IF(MasterLocal.Flushed != MasterLocal.Issued)
				flush();

			IF!(++attempt & 1023)
			{
				start := NOW;
				IF((NOW) - start > 250 * MEGA)
				{
					term::error(at,
						Job::name(),
						" THREAD FROZE / DIED. C:", std::io::format::dec(MasterLocal.Consumed),
						" I:", std::io::format::dec(MasterLocal.Issued),
							"/", std::io::format::dec(Master.Issued(:<)),
							"/", std::io::format::dec(MasterLocal.Flushed),
						" P:", std::io::format::dec(MasterLocal.SeenProcessed),
							"/", std::io::format::dec(Slave.Processed(:<)),
						" Q: ", Shared.Quit(:<) ?? "TRUE"[#] : "FALSE"[#]);
				}
			}
			MasterLocal.SeenProcessed := Slave.Processed( :< );
			PAUSE;
		}
			}

		start ::= MasterLocal.Consumed % ##Constant.Outputs;
		end ::= MasterLocal.SeenProcessed % ##Constant.Outputs;

		ret: Job::Output+[#];
		IF(end > start)
			ret := Constant.Outputs[FROM start UNTIL end];
		ELSE
			ret := Constant.Outputs[FROM start];
		MasterLocal.Consumed += ##ret;
		= ret;
	}
}

::rlc::compiler [Job; #Cap] PipelineSetup -> [Job]Pipeline
{
PRIVATE:
	Worker:                Job;
	Inputs:   @(CACHELINE) Job::Input+[Cap];
	Outputs:  @(CACHELINE) Job::Output+[Cap];
	Thread: VOID^;
PUBLIC:
	[Args...]{args:Args!&&...} -> (Inputs, Outputs, &Worker):
		Worker(<Args!&&>(args)...),
		Inputs(BARE),
		Outputs(BARE);

	launch_worker() VOID {
		worker ::= ->([Job]Pipeline).launch_worker();
		Thread :=: worker;
		->([Job]Pipeline).wait_launched();
	}

	// ONLY MASTER
	join(at: WHERE, timeout_ns: U8) VOID
	{
		IF!(->([Job]Pipeline).MasterLocal.Threaded) RETURN;

		IF!(Thread[timeout_ns])
			term::error(at, Job::name(), " thread is stuck!");
	}

	PRIVATE {#&} { DIE; }
}