::rlc::compiler [Job] Pipeline
{
	// shared constant state.
	ConstantR {
		State: Job *;

		Inputs: Job::Input+[#];
		Outputs: Job::Output+[#];
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
	Constant: ConstantR #;
	MasterLocal: MasterLocalR;
	Master: MasterR;
	Slave: SlaveR;
	SlaveLocal: SlaveLocalR;
	Shared: SharedR;

	{#&} (BARE) { DIE; }
	{&&} (BARE) { DIE; }

	{inputs: Job::Input+[#], outputs: Job::Output+[#], state: Job *}:
		Constant (state, inputs, outputs)
	{
		ASSERT(##Constant.Inputs == ##Constant.Outputs);
	}

	DESTRUCTOR { Shared.Quit := :>(TRUE); }

	PRIVATE worker_thread() VOID
	{
		Master: MasterR # & := THIS.Master;
		Constant: ConstantR #& := THIS.Constant;
		Slave: SlaveR & := THIS.Slave;
		Shared: SharedR & := THIS.Shared;

		processed ::= Slave.Processed(:<);
		Shared.Quit := :>(FALSE);

			start_waiting ::= CPU_COUNTER;

		WHILE(!Shared.Quit(:<))
		{
			issued ::= Master.Issued(:<);
			IF(issued == processed)
				CONTINUE;

				start_processing ::= CPU_COUNTER;
				end_waiting ::= start_processing;
				SlaveLocal.Waiting += end_waiting - start_waiting;

			WHILE(processed != issued)
			{
				Constant.State->handle_job(
					Constant.Inputs[processed % ##Constant.Inputs],
					&Constant.Outputs[processed % ##Constant.Outputs]);
				++processed;

				Slave.Processed := :>(processed);
			}

				start_waiting := CPU_COUNTER;
				end_processing ::= start_waiting;
				SlaveLocal.Processing += end_processing - start_processing;
		}
		Shared.Quit := :>(FALSE);
	}

	wait_launched() VOID --
	{
		tries: U4 := 0;
		start ::= NOW;
		WHILE(Shared.Quit(:<))
		{ IF!(tries++ & 255) { IF((NOW)-start > 100000000) DIE; } }
	}

	launch_worker() VOID^
	{
		MasterLocal.Threaded := TRUE;
		thread: VOID^(^worker_thread());
		wait_launched();
		= &&thread;
	}

	next_input() Job::Input \
	{ // AS MASTER
		ASSERT(MasterLocal.Issued - MasterLocal.Consumed < ##Constant.Inputs);

		= &Constant.Inputs[MasterLocal.Issued % ##Constant.Inputs];
	}

	[Args...]issue(input: Args!&&...) VOID --
	{ // AS MASTER
		ASSERT(MasterLocal.Issued - MasterLocal.Consumed < ##Constant.Inputs);

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

	quit() VOID -- { Shared.Quit := :>(TRUE); } // AS MASTER
	wait_quit(at: WHERE) VOID --
	{ // AS MASTER
		IF!(MasterLocal.Threaded) RETURN;

		start ::= NOW;
		attempt ::= 0;
		WHILE(Shared.Quit(:<))
		{
			IF!(attempt++ & 255)
				IF((NOW) - start > 100000000)
					term::error(at, Job::name(), " thread is stuck!");
		}
	}

	/// Sends pending work to the worker. This also gets called automatically.
	flush() VOID -- { // AS MASTER
		Master.Issued := :!(MasterLocal.Issued);
		oldFlushed # ::= MasterLocal.Flushed;
		MasterLocal.Flushed := MasterLocal.Issued;

		IF!(MasterLocal.Threaded)
		{ // AS SLAVE
			end ::= MasterLocal.Flushed;
			FOR(i ::= oldFlushed; i < end; i++)
				Constant.State->handle_job(
					Constant.Inputs[i % ##Constant.Inputs],
					&Constant.Outputs[i % ##Constant.Outputs]);
			Slave.Processed := :!(end);
		}
	}

	[Args...]issue_flush(input: Args!&&...) VOID --
	{
		THIS.[Args!...]issue(<Args!&&>(input)...);
		flush();
	}

	# full() BOOL := MasterLocal.Issued - MasterLocal.Consumed == ##Constant.Inputs;
	# pending() U4 -- := MasterLocal.Issued - MasterLocal.SeenProcessed;

	get_some(at: WHERE) Job::Output+[#]
	{ // AS MASTER
		IF(!pending())
			= NULL;

			{
		start ::= NOW;
		attempt: U4 := 0;
		WHILE(MasterLocal.Consumed == MasterLocal.SeenProcessed)
		{
			IF(MasterLocal.Flushed != MasterLocal.Issued)
				flush();

			IF!(attempt++ & 255)
			{
				IF((NOW) - start > 250000000)
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
	{} -> (Inputs, Outputs, &Worker): Inputs(BARE), Outputs(BARE);

	launch_worker() VOID {
		worker ::= ->([Job]Pipeline).launch_worker();
		Thread :=: worker;
		->([Job]Pipeline).wait_launched();
	}

	PRIVATE {#&} { DIE; }
}