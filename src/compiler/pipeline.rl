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
		IdleHook: ((VOID*) VOID) *;
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
	Constant: @(CACHELINE) ConstantR;
	MasterLocal: @(CACHELINE) MasterLocalR;
	Master: @(CACHELINE) MasterR;
	Slave: @(CACHELINE) SlaveR;
	SlaveLocal: @(CACHELINE) SlaveLocalR;
	Shared: @(CACHELINE) SharedR;

	{#&} (BARE) { DIE; }
	{&&} (BARE) { DIE; }

	{inputs: Job::Input+[#], outputs: Job::Output+[#], state: Job *}:
		Constant (state, inputs, outputs, NULL, NULL, NULL, NULL)
	{
		ASSERT(##Constant.Inputs == ##Constant.Outputs);
	}

	DESTRUCTOR { Shared.Quit := :>(TRUE); }


	PUBLIC run_worker(thread_mask: U8) VOID {
		MasterLocal.Threaded := TRUE;
		worker_thread(thread_mask);
	}

	PRIVATE worker_thread(thread_mask: U8) VOID
	{
		Master: MasterR # & := THIS.Master;
		Constant: ConstantR #& := THIS.Constant;
		Slave: SlaveR & := THIS.Slave;
		Shared: SharedR & := THIS.Shared;

		__rl::set_thread_affinity(thread_mask);

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

			hook: U8 := 0;
			WHILE(processed != issued)
			{
				output ::= &Constant.Outputs[processed % ##Constant.Outputs];
				Constant.State->handle_job(
					Constant.Inputs[processed % ##Constant.Inputs],
					output);
				++processed;


				// TODO CAUTION: make sure we still have access to the output during the post job hook.
				IF(Constant.PostJobHook)
				{
					hook_start ::= CPU_COUNTER;
					Constant.PostJobHook(Constant.HookCtx, *output);
					hook += CPU_COUNTER - hook_start;
				}

				Slave.Processed := :>(processed);
			}

				start_waiting := CPU_COUNTER;
				end_processing ::= start_waiting;
				SlaveLocal.Processing += (end_processing - start_processing) - hook;

			IF(Constant.IdleHook) Constant.IdleHook(Constant.HookCtx);
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

	launch_worker(thread_mask: U8) VOID^
	{
		MasterLocal.Threaded := TRUE;
		thread: VOID^(^worker_thread(thread_mask));
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
		oldFlushed # ::= MasterLocal.Flushed;
		MasterLocal.Flushed := MasterLocal.Issued;
		// release the master-local state, so that the worker thread can read it, too.
		Master.Issued := :>(MasterLocal.Issued);

		IF!(MasterLocal.Threaded)
			flush_st(oldFlushed);
	}

	PRIVATE flush_st(oldFlushed: U4) VOID { // AS SLAVE
		end # ::= MasterLocal.Flushed;
		IF(end == oldFlushed) RETURN;
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

		IF(Constant.IdleHook)
			Constant.IdleHook(Constant.HookCtx);
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

	sync() VOID -- { // AS MASTER
		MasterLocal.SeenProcessed := Slave.Processed(:<);
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
	Worker:   @(CACHELINE) Job;
PRIVATE:
	Inputs:   @(CACHELINE) Job::Input+[Cap];
	Outputs:  @(CACHELINE) Job::Output+[Cap];
	Thread: VOID^;
PUBLIC:
	[Args...]{args:Args!&&...} -> (Inputs, Outputs, &Worker):
		Worker(<Args!&&>(args)...),
		Inputs(BARE),
		Outputs(BARE);

	launch_worker(thread_mask: U8) VOID {
		worker ::= ->([Job]Pipeline).launch_worker(thread_mask);
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