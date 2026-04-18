INCLUDE "types.rl"
::rlc::compiler::type
{
	// Something that a bytecode operation is performed on. We want to batch processing based on value type and operation. Also, if we batch based on that, we also do not need to store the value tag.
	// TODO: How do we unify this with values and code generation?
	UNION InterpreterState { // IMPORTANT: keep below 32 entries.
		BuiltinType: tok::BuiltinType; // U1 etc.
		Void;
		Null;
		This;
		ThisNoDecay;
		SymbolType: Identifier; // :name
		TemplateSymbolType: Identifier; // :name.T
		SpecialSymbolType: U2; // :? etc.

		UserType: U2; // User type ID.
		TaggedUnion: U2; // User type ID of Union.
		EnumTag: U2; // User type ID of Union.
		TemplateType: U2; // Idx of template in surrounding context? (T)

		NonNullPointer;
		MaybePointer; // T -> T *
		Array;
		AutoArray;
		Table;
		Slice;
		SizedSlice;
		Atomic; // TODO: Do we want this as a qualifier or as an indirection? Ideally, we want to allow non-atomic writes and reads for atomic values (such as for memcpy when we are the current owner). Actually, atomic is a level of sharedness? But INT.[?] is not INT[?]., because we do need to be clear on what piece of data has to be atomically updated. I think for now, we should only allow atomics on primitive types and pointers. If we have atomics here, we can leverage them into their own SWITCH case, without having to do manual IFs for checking the flag.

		TupleType;
		FnSigType;
	}

	(/ PLAN FOR THE TYPE PROCESSOR

	We interleave the T1 / Input ByteCode stream with a fixed stride (not too large to under-use pages too much. Maybe 64-256 or something. Also, not too small to no longer benefit from batching.) During processing, we can then operate on a tightly packed stream of n-th bytecode of each type, which will cause few cache misses despite the random access.

	The T2 / output ByteCode could also be interleaved, and then we do a post-pass over it, de-interleaving it, but packing it in a linear allocator or something, so that we still get good locality. We can then also try to dynamically pad them out so that they fit a single cacheline if possible.

	The ByteCode is actually already going to be the full IR, probably, so it might get merged with the expression / statement bytecode. Although that would create a needlessly large union, maybe?

	During processing, in the happy case, we only touch one cacheline of interpreter state per type (InterpreterHot).

	/)


	UNION T2ByteCode {
		MakeVoid;
		MakeNullType;
		MakeTuple: U2; // number of tuple elements.
		MakeFnSig: U2; // number of arguments.
		MakeTemplateSymbolType: Identifier; // Prefix: turn next type into template arg for symbol type.
		MakeSymbolType: Identifier;
		MakeThisType: BOOL; // Whether it is nodecay
		ExpandTemplateTypes: U2; // Idx of template pack, expand it. (Args...)

		MakeBuiltinType: tok::BuiltinType;

		TypeInstance: U2; // Instance ID of a template type.

		(/ For when we merge types and expressions:

		BaseFunction: U2; // uninstantiated form of the function, by ID.
		InstantiateFunction: U2; // template arguments.
		AddressOfFunction;
		InlineFunction: U2; // number of invocation arguments.
		CallFunction; // number of invocation arguments.
		/)

		TemplateType: U2; // index of template type in surrounding context's template stack.
		TemplateTypeNoDecay: U2;

		// Defer a child lookup to instantiation time.
		LookChildType:  Identifier;
		LookChildValue: Identifier;
		LookChildScope: Identifier;

		// Template-dependent template instantiations that are not statically knowable.
		InstantiateTemplate: U2; // Idx of template arguments to apply to the bytecode.
		PushAsTemplate; // Abort current type and push it onto template argument stack.
		PushTemplatePack: U2; // number of template parameters.
		PushAsVariadicTemplatePack;
		AddTemplatePacks: U2;
		AddTemplateArg; // Prefix op: add this to the template arguments of the next type leaf. Execute this at symbol end or before the next AddTemplateArg. We can actually apply templates automatically in LookChildType, maybe? Based on precedence rules.

		AddModifier: types::PackedModifier; // when adding any modifiers.
		MakeArray;
		MakeTable;
		MakePointer;
		Dereference; // element of pointer or array, or result of *THIS/THIS-> operator.
		GetUnionTag; // Is a prefix operation!
		MakeTaggedUnion;
		Instantiate; // When instantiating a variable... Is this a necessary opcode, though?
		AccessTupleField: U2; // .(Index)
		FieldAccess: U2; // .(:Field)
	}

	TypeOutput {
		// :vec(:a.INT(5), :a.INT(4));
		Code: T2ByteCode[16];
		Extension: T2ByteCode[#];
	}


	ENUM Precedence {
		normal
	}

	InterpreterHot {
		// Hot state / tip
		// 3
		State: @(CACHELINE) TAGGED InterpreterState; // tip of the stack / innermost type.
		// 1
		LastPrecedence: U1; // is this redundant with "Queue"? As it also remembers precedence.
		// 3* ? = ?
		CallStack: :CallStackEntry[3];
		// 3*4 = 12
		Stack: { TAGGED InterpreterState, Precedence }[3];
		// 3*? = ?
		TemplateStack: :?[3];
		// 2*2 = 4
		TemplatePacks: U2[2];
		// 8
		RemainingCode: TAGGED types::ByteCode[];
		// 4
		RelativeNs: scoper::Namespace -Handle;
		// 8
		RelativeMembers: parser::Members *;
		// 3+1+12+4+8+4+8 = 40 + ? + ? => 24 hot bytes left over.

		Queue: U4; // Bitmask of precedences.   -4 = 20 hot bytes left over.
		QueuedOps: U4; // ENUM types::ByteCode[4]; // Precedence-sorted array of queued operations. -4 = 16 hot bytes left over.
		Output: T2ByteCode[]; OutputLength: U2; // -10 = 6 hot bytes left over.

		// TODO: use initialising constructor that takes the ByteCode etc. as args.
		{}:
			State(BARE),
			CallStack(BARE),
			Stack(BARE),
			TemplateStack(BARE),
			TemplatePacks(BARE);
	}
	// TODO: Migrate all cold storage into one interleaved cold storage for all interpreters, stored on the processor.
	InterpreterCold
	{
		// Stack
		CallStack: :CallStackEntry-std::Vec;
		Stack: { TAGGED InterpreterState, Precedence } - std::Vec; // nested / outer types.
		TemplateStack: :? - std::Vec;
		TemplatePacks: U2 - std::Vec;
		// Huge. Do we want to lazily allocate this?
		Queue: TAGGED types::ByteCode -std::Vec[TABLE Precedence];
	}

	Interpreter {
		Hot: @(CACHELINE) InterpreterHot;

		advance() ENUM types::ByteCode -- {
			Hot.RemainingCode := Hot.RemainingCode[FROM 1];
			= Hot.RemainingCode->(0);
		}
		# start() types::ByteCode -- := Hot.RemainingCode->(1);

		Cold: InterpreterCold;

		gtype_id(scoper::Namespace::Entry *) U2 { DIE; }
		mtype_id(parser::Members::NVEntry *) U2 { DIE; }


		MakeVoid() VOID -- { Hot.State := :Void; }
		MakeNullType() VOID -- { Hot.State := :Null; }
		MakeTuple() VOID -- {
			arity ::= start().MakeTuple;

		}
		MakeSymbolType(op: types::ByteCode) VOID --
			{ Hot.State := :SymbolType(op.MakeSymbolType); }
		MakeThisType() VOID --
		{
			Hot.State := start().MakeThisType
				?? <TAGGED InterpreterState>(:This)
				:  <TAGGED InterpreterState>(:ThisNoDecay);
		}
		MakeBuiltinType() VOID --
			{ Hot.State := :BuiltinType(start().MakeBuiltinType); }
		LookRootType(rootScope: scoper::Namespace *) VOID --
		{
			entry ::= rootScope->lookup_t(ident::get_global_decl(start().LookRootType));
			Hot.State := :UserType(gtype_id(entry));
		}
	}



	// Requests[]
	// Interpreters[]
	//  -- Group by operation for homogeneous code paths

	ByteCodeSpan {
		Start: U4;
		End: U4;
	}



	TYPE InterleavedByteCodes := TAGGED types::ByteCode[128];
	MAX_REQUESTS: U4 # := ###InterleavedByteCodes;

	RequestContext { Ns: scoper::Namespace \; Ms: parser::Members *; }

	RequestBatch
	{
		Code: InterleavedByteCodes[#]; // Bytecode sequences of all requests, interleaved and concatenated.
		Contexts: RequestContext[###InterleavedByteCodes];
		Count: U2; // number of requests.
		Positions: src::Position[#];
		RequestsByStartingByteCode: ByteCodeSpan[#][TABLE ENUM types::ByteCode]; // Per starting bytecode: bucket of bytecode sequences.
	}

	// Ring buffer.
	Bucket {
		Start: U2; End: U2;
		Array: Interpreter *[1024];

		insert_if(do: BOOL, job: Interpreter *) VOID --
		{
			Array[End % ##Array] := job;
			End += do;
		}
	}


	// Many bytecode interpreters.
	Processor {
		Requests: RequestBatch;
		Interpreters: Interpreter[1024];

		Buckets: Bucket[TABLE ENUM types::ByteCode];

		RootScope: scoper::Namespace \;

		[Args...]fail(at: U4, args: Args!&&...) VOID
		{ term::error(Requests.Positions[at], <Args!&&>(args)..., " (type interpreter)"); }

		handle_job_after_step(state: Interpreter *) VOID --
		{
			nextOp ::= state->advance();
			ended ::= (<U1>(nextOp) == ### ENUM types::ByteCode);
			Buckets[nextOp].insert_if(!ended, state);
		}


		MakeVoid(jobs: Interpreter *[#]) VOID
		{
			FOR(jobs) {
				IT->MakeVoid();
				handle_job_after_step(IT);
			}
		}

		MakeNullType(jobs: Interpreter *[#]) VOID
		{
			FOR(jobs)
			{
				IT->MakeNullType();
				handle_job_after_step(IT);
			}
		}

		MakeTuple(jobs: Interpreter *[#]) VOID
		{
			FOR(jobs)
			{
				IT->MakeTuple();
				handle_job_after_step(IT);
			}
		}
	}
}