INCLUDE "../../ir/type.rl"

::rlc::compiler::typededup {

	(/ Master plan:

	Following the bootstrap compiler's order, we do this:
		- [X] (1) We first resolve all type declarations
		- [X] (1) We declare all global variables
		- [X] (1) We declare all global functions
		- [ ] (2) We resolve all typedefs where possible.
		- [ ] (2) We implement all types (resolving class fields, etc.)
		- [ ] (2) We resolve all function signatures (parameter & return types)
		- [ ] (2) We implement all variables (initial values etc.)
		- [ ] (2) We implement all functions (bodies)

	However, there can occasionally be dependencies between types, variables, and functions that do not follow this order, but this order should be conflict-free 99% of the time. So now the question is: do we perform multi-pass or recursive/transitive resolution? If we perform transitive resolution, we do not need an intermediate representation that would need patching. However, this would also not be well-threadable. We want no contention on the job.

	What cases of types are there?
		- (a) primitive types
		- (a) names of user-defined types, like classes
		- (b) names of typedefs
		- (c) template-independent template-instantiations of types  ((a) + (a) template)
		- (d) template-dependent type references
		- (e) auto/typeof references, which require expression typechecking, value-dependent types (array bounds)

	All (a) type references are trivially resolvable once the global scope tree exists.
	(b) types are also trivially resolvable to the typedef they refer to, but that itself might also be any case. If we can ensure that all (a)-type typedefs are distinct from other typedefs, then we can also resolve these trivially.
	(c) types require the instantiator and a deduplicator for the handle. But the handle itself can already be allocated.
	(d) types can be deduplicated, but not fully resolved until the surrounding context is also instantiated.
	(e) types are the most tricky ones, because they can cycle arbitrarily.

	If we can split all typing work into these cases first, then we can solve almost all of the work with a parallelisable resolver. (a) references are parallelisable, and we can assign the type IDs ahead of time, and resolution is just a lookup of the type's predefined ID. (b) references get categorised as the same type as the typedef. (c) references need deduplication. (d) references can be prepared for easier instantiation.

	The categories have different costs for their resolution and can be resolved using different algorithms. We need one classifying pass, which can be parallelised. Though for primitive types, classification is more expensive than resolution.

	When instantiating a class, we want to know what tasks are still left over. So we want to do something similar to TRASM (see blog post), where we have local constants that need resolution, and some code that resolves them. The rest of the code refers to these slots. Then, we can do one final pass where all things that depend on templates can get deduplicated or patched up. Though we really don't need deduplication for things except template instantiations. However, when dealing with template-dependent things like that, we want to deduplicate the request. We could do that by remembering on the template type the things which we requested already, and what slot they belong to. If this process takes little working memory, we can parallelise this well.

	So we basically have a typechecking prepass which resolves (a) references and prepares work for the post-pass and for the instantiator. This way, we can also determine the ratio to which a templated function depends on a template, which could help make informed choices about code deduplication vs. performance. Large template-independent sections could be deduplicated into function calls, and the template-dependent sections might also be either inlined or deduplicated across types, such as FOR(T) IT.{};, which could also become a reusable function.

	So we have the following stages:

		2.1: categorisation pass & (a)-type resolution, as well as preparation for instantiator.
			2.1.0: It might help to first go through all typedefs globally beforehand, so that we know exactly what category a typedef is.
			2.1.1: All other type occurrences.
		2.2: Go through all (c) types.
		2.3: Go through all (d) types.
		2.4: Go through all (e) types.

	The final stages are not clearly separable, as they can generate more work for the other stages at any point. We might want to split 2.1. into primitives and symbols, so that we can handle symbol lookups in a special loop that amortises the pointer chasing. So we want to generate a bytecode description of all type references, and also classify them or split them up based on their class. Then we can resolve all (a)-type segments of all types at once, even if the type also contains other parts. All (e)-type segments are then also processed at once, etc.

	Potential algorithm for each stage:
		1. Take a bytecode sequence
		2. Apply first opcode to it
		3. Put it in a bucket based on the next opcode.
		4. Fetch next bytecode sequence in the current bucket.

		The algorithm would use double buffering for the buckets, so that the current bucket may generate new work for the next iteration. Then, we can have one bucket per operation, and even one per operation & input value. Then we do not regain context per item, but rather have batches based on shared situations, and then have fixed logic per batch, and only need to check whether a batch exists. We can even speed up the checking if we use a virtual call per batch and then have a bitmask for whether a batch is empty or not. Though this might not even be worth it. We can think about it later. So we do a breadth-first loop over all types.

		~~We could additionally have threads that only cover a subset of all cases, and then when they are done, they could swap the buffers or something… though then we have multiple writers per bucket, so that is not good.~~

		Even though this approach is highly performant, we might still want to have a more parallelisable or pipelinable approach. The problem is that it seems like each bucket can generate more work for each other bucket. The only thing that would matter is if we are done with resolving a type, reaching the :EOF of a bytecode sequence. That could then be deduplicated for example. Or if there is one bucket that is way more expensive to process than the others, it might be worth it to put that in another thread, despite the fact that it can (can it, though???) generate more work for the main thread, causing contention.

		If this is not parallelisable, we could also use the time that this happens at to do something completely unrelated, like loading .ELF files that we want to link against, and preparing them for code generation. Additionally, we could also already generate JIT code for the instantiator and code generator, based on the types that are already resolved. Or some kind of processing of function bodies.
	/)







	(/ NEW Flow:

	1. [X] Preprocessing step:
		We process all scopes in the global scope tree to allow for easier lookups.
	2. [/] Parsing step:
		We parse all types into a stream of bytecode for the type resolver. Even multiple type instances could be fit into that one big stream. We pass around chunks of bytecode, maybe up to 1024 operations at a time (??). The type resolver can then execute those linearly. Additionally, we can pass an array containing the start markers for the bytecode sequences, indicating where each type in the sequence starts.
			-- [/] Finish type parsing logic
			-- [ ] Finish bytecode generation & design
	3. [ ] Processing / resolving step:
		The resolver processes the bytecode and spits out resolved types (also resolving scope names etc.).
			-- [/] Type bytecode processor
	4. [ ] Deduplication step:
		We can deduplicate all processed types in the hashmap, assigning them compact IDs. We do not want to deduplicate unfinished types, though (such as those depending on templates). So a Type ID is probably a mempool handle and a flag, indicating whether they are fully resolved or not. We may want to give them running numbers like for identifiers. And we also want to differentiate between types that ever occur in a type switch / TYPE() expression and those that do not. This way, we can keep those numbers/tables dense and small.
			-- We do not want to deduplicate tuple types passed to constructors (especially for arrays and tables), or types of similar transient values. We might only want to do that for signature types, return types, and variable types. Everything else gets thrown away after first use anyway, and would only clutter the mempool & hashtable needlessly.
	5. [ ] Body parse:
		We start parsing function bodies etc., which can then assume that all publicly reachable symbols are fully typed / resolved already (except for template-dependent type references and auto types). We need to typecheck expressions and also resolve references to local variables in this step, and already prepare the IR for the code generator. Since function bodies are highly heterogeneous, we might want to split a function body into many separate statements that can then be typechecked simultaneously. The problem is the sequential dependency within a function body. But we could definitely typecheck multiple function bodies in a batch. 
			-- We could also introduce a preliminary step that parses all expressions that are needed to fully resolve all exposed auto-types (auto function signatures, global auto variables, etc.). Then we can have the next step be more optimised.
	6. [ ] Expression typechecker & IR generator:
		We process the IR0 streams of multiple functions in an interleaved manner, if possible. Register pressure could make that less efficient, though. We output the IR1. Actually, we have a slight problem because we need to know whether a variable is used for the last time, because definite last use means we generate a destructor call and also give it move semantics. This means type checking cannot be done until we know the last use. So we first need to know the full function body, then flag all last usages, and only then we can generate IR1 code and typecheck.
			-- TODO: define clear rules for last-use analysis and its interaction with nop elimination: specifically, whether a nop-eliminated last use changes the type of the previous use by promoting it into a last use.
	7. [ ] Instantiator:
		After having the IR1 for all code in the entire project, we take the IR1 and instantiate templates and do inlining, etc.. One problem, though, with templates, is that we do not know whether a template call is going to be a nop, and whether that should count as last use for the parameters or not. On the other hand, we do not want to complicate the system too much, and we also do not want destructors to be moved forward by apparent keepalive calls that turn out to be nops sometimes. Or do we? We could have explicitly strict destructors for variables where we rely on side-effects like that.
	8. [ ] Optimiser? -- nop elemination, code transformation, etc. -- not needed for now. Though we do want to eliminate nops already, I think. But no need for tryhard optimisations.
	9. [ ] Codegen:
		At first, we want to directly run the optimised IR code in an interpreter. This will let us build a good debugging experience that does not depend on ELF/DWARF and other platform- and architecture-dependent technologies. This would also allow for debugging from within a browser, etc.. Then we only need an IR interpreter for each platform, which should be quite manageable.
		Afterwards, we can add native code generation backends for the various platforms.



	Observations:
		- Step 1 and 2 can be run in parallel. The resolver needs step 1 to be fully completed, but can perform work on the parser's output before it fully finishes.
			- This means we probably want to set up a pipeline that lets the parser continuously feed new work into the type resolver.
		- We probably also want to first generate all IR0 for everything.
		- If we want to have unique instantiations, then we probably need the instantiator to be a single worker thread. We would then need some kind of request-response IPC flow. This means instantiations would be asynchronous. What we can do is request all instantiations for all functions in one huge batch, and then continue typechecking stuff that does not need instantiations.
			-- Inlined functions etc. should be instantiated in-line as well, so they do not need to go through a deduplication step, and we can directly substitute the IR & placeholders. Only classes and non-inline functions should go through deduplication for the instantiation.
				-- We already know whether a function is inline or not, at the time we encounter its invocation. So we can immediately decide what to do with it.
			-- A template instantiation's arguments might rely on the result of another template instantiation before it, so they cannot be instantiated within one batch request. But since we have lots of functions that we can process bit-by-bit in a round-robin fashion, that latency should not matter too much. We simply execute one round, gathering up all the template instantiations we need, and pass them to the instantiator thread. Then we process the rest of the round. We can actually have two work queues: one of functions that can proceed immediately, and one for functions that need to wait for the instantiator to proceed. After each step, a function gets assigned to either queue based on what was encountered.
	/)




	ENUM Indirection {
		Reference,
		Pointer,
		NonNull,
		SizedSlice,
		UnsizedSlice,
		Atomic, // maybe this should be a qualifier instead?
		Future
	}

	(/Qualifier { // NOTE: Could be compressed to 3 bits.
		Const: Constness;
		Shared: Sharedness;
	}/)

	Modifier {
		Indirection: typededup::Indirection;
		Qualifier: typededup::Qualifier;
		{BARE};
	}

	(/ Example:

		std::io::File
			start: (Surrounding scope)
			code: ChildScope(std).ChildScope(io).ChildType(File)

		std::[INT]Vector
			start: (Surrounding scope)
			code: ChildScope(std).ChildType(Vector).InstantiateTemplate(0)
			ctx.0: BuiltinType(INT)

		::std::[INT]Vector
			start: (root scope)
			code: ChildScope(std).ChildType(Vector).InstantiateTemplate(0)
			ctx.0: BuiltinType(INT)

		std::[std::[INT]Vector]Vector
			start: (Surrounding scope)
			code: ChildScope(std).ChildType(Vector).InstantiateTemplate(0)
			ctx.0: ChildScope(std).ChildType(Vector).InstantiateTemplate(1)
			ctx.1: BuiltinType(INT)
	/)


	PerScopeLookupRequestBatch {
		Start: :Scope *;
		Requests: U2;
	}
	LookupRequest {
		ContextCount: U2;
	}

	(/ DATA LAYOUT:

		{ -----------  request 0 ------------------------}{-- request 1 -}{-- request 2 -}
		[main segment 0][ctx segment 0.0][ctx segment 0.1][main segment 1][main segment 2]...


		One stream of bytecode, split into segments. Each request has one main segment, followed by arbitrarily many context segments.
	/)

	Segment {
		StartGlobal: BOOL;
		Start: U2;
	}
	RequestBatch {
		PerScopeBatches: PerScopeLookupRequestBatch[#];
		Requests: LookupRequest[#];
		Code: ByteCode[#];
		Segments: Segment[#]; // Length implicitly stored.
		Segments_Global: U1[#]; // bit-array of Segment.Global, indicating whether to use global scope.
		Results: U2[#]; // NOTE: we may want to make sure that the dedupler can write to this without having to steal it from another core.
	}


	// We want TypeCore + TypeMod[]. TypeCore contains the atoms, like user types, builtins, and symbol types. TypeMod contains arrays and other things that composit over types.
	UNION TypeMod {
	}

	// Additional data for a type.
	TypeMeta { // NOTE: could be compressed to one byte (6 bits).
		Qualifier: typededup::Qualifier; // 3
		Lifetime: ir::Lifetime;          // 3
		{BARE};
	}

	

	// Processing a type, we sort the operations into precedence groups. If we encounter a new operation that does not take precedence over the next queued-up operation, we execute the other operation first.
	Precedences: U1[TABLE ENUM ByteCode];

	FullState { // NOTE: could be compressed to just 4 bytes:
		Meta: TypeMeta;          // 1 byte      | 6 bits
		Kind: ENUM TypeCore;     // 1 byte      | 5 bits = 11
		//                          1 byte free | 5 bits = 16, could be used for extra tag.
		Core: typededup::TypeCore; // 2 bytes

		{BARE};
	}


	::extra {
		UNION ArrayInfo {
			ResolvedSize:   U4; // let's not allow arrays larger than 4 billion entries.
			UnresolvedSize: U4; // expression handle.
		}

		UNION TableInfo {
			Enum: parser::Enum-Handle;
			UnionTag: parser::Union-Handle;
		}
	}

	UNION ExtraTypeInfoTag { // should be compressable to 3-4 bits
		Array: ENUM extra::ArrayInfo;
		Table: ENUM extra::TableInfo;

		Raw: U1;
	}
	UNION ExtraTypeInfo {
		Array: extra::ArrayInfo;
		Table: extra::TableInfo;
	}

	PackedExtendedState {
		Bits: U4;
		Extra: ExtraTypeInfo;

		# kind() ENUM TypeCore := >(Bits & 31);
		set0_kind(v: ENUM TypeCore) VOID -- { Bits |= <U4>(v); }

		# constness() Constness -- := >(Bits >> 5 & 3);
		set0_constness(v: Constness) VOID -- { Bits |= <U4>(v) << 5; }

		# sharedness() Sharedness -- := >(Bits >> 7 & 1);
		set0_sharedness(v: Sharedness) VOID -- { Bits |= <U4>(v) << 7; }

		# lifetime() ir::Lifetime -- := >(Bits >> 8 & 7);
		set0_lifetime(v: ir::Lifetime) VOID -- { Bits |= <U4>(v) << 8; }

		# extra_tag() ExtraTypeInfoTag -- := :Raw(Bits >> 11); // & 31 implicit.
		set0_extra_tag(v: ExtraTypeInfoTag) VOID -- { Bits |= <U4>(v.Raw) << 11; }
	}


	FixedType {
		Stages: FullState[#];
		AdditionalInfo: ExtraTypeInfo[#];
	}

	LiveType {
		StartGlobal: BOOL;
		Code: ByteCode-std::Vec;
		Stages: FullState - std::Vec;
	}

	(/ Type & constant evaluation:

		- Types are always compile-time constants.
		- Types may involve numeric constants (array sizes)
		- Types may need to be resolved in order to resolve a numeric constant (SIZEOF).
		- Types may refer to other types that first need to be resolved (typedefs, etc.)

	This means we might need one unified comptime constant evaluator that handles both kinds of constants. The causal dependencies between types and expressions either require nonsequential processing, or multi-pass processing.
		- If we do not process sequentially, then that means a service/request model won't properly work, as the service will have to fetch additional tasks.
		- If we do multi-pass processing, then we might need less effort. Things that have already been fully processed should then get eliminated from the work set. We can do that by accumulating a revisit-list of not fully resolved tasks, which gets cleared and rewritten every time.
			- We can detect dependency locks by also remembering whether a type made any progress or not. If none made any progress, then we are stuck. Additionally, we can just do a maximum number of runs after which we terminate.
	/)

	// We want to have a minimal working set in the cache. A prefix tree might unnecessarily fragment the memory or make use touch unnecessarily many cachelines. It might turn out that a deduplicated type ID and a hashmap for deduplicating type encodings is sufficient.
	TypePrefixTree {
		Node: ByteCode; // Actually known from context.
		ID: U2;
		Children: TypePrefixTree *[TABLE ENUM ByteCode];
	}

	TypeDescriptor {
		Code: ByteCode[#]; // Restriction: cannot contain TemplateType or InstantiateTemplate.
	}

	(/ Type processing:
		We have a stack machine & bytecode stream with reverse polish notation to describe types. Some bytecodes just add something to the type (:Modifier), while others start a new type sequence (:BuiltinType), and others consume entire types (such as the :InstantiateTemplate code). When a new type is started, we push a new type sequence to the stack and all further modifications affect this type. Consuming operations deduplicate the consumed types and replace them with their TypeId, and then perform the consuming operation with those TypeIds as inputs.
		Value template arguments, for now, should be constrained to numbers only. Although we could also add some more sophisticated compile time execution. But that will also require instantiation and all that stuff, too. Maybe we should resolve expressions later, so that for now, only types get deduplicated.
	/)

	Context {
		Starts: U2-std::Vec;
		Stream: ByteCode-std::Vec;
	}
}

::rlc::compiler TypeDeDupler
{
	Output {
		Tokens: @(CACHELINE) tok::FileTokenView;
		LocalIds: U2;
		File: src::File;
		// TODO: Do we want to pass the lookup of local to global IDs / global to local? Actually, we would want this at a later stage, probably.
	}

	Input {
		RequestCount: @(CACHELINE) U4;
	}

	// Parser stack and temporaries.
	PRIVATE Alloc: std::temp::Alloc;

	Out: typededup::LiveType;

	Current: U4;
	Starts: U4-std::Vec; // starting location of unfinished types.

	start() VOID -- { Starts += Current; }
	finish_type() VOID -- {
		Starts.pop_back(&Current);
	}

	nest_value() VOID {}
	nest_type() VOID {}
	resume() VOID {}

	parse_type_mods(parser::Parser &) VOID { }

	parse_type(p: parser::Parser &) VOID
	{
		SWITCH(p.type())
		{
		:Identifier: {
			Out.StartGlobal := FALSE;
			parse_type_symbol_child_no_tpl(p);
		}
		:Punctuation:
			SWITCH(p.stype().Punctuation)
			{
			:doubleColon: {
				Out.StartGlobal := TRUE;
				parse_type_symbol_child_no_tpl(p);
			}
			:bracketOpen: {
				Out.StartGlobal := FALSE;
				p.next();

				IF!(p.consume_s(:Punctuation(:bracketClose)))
				{
					DO()
					{
						IF(p.consume_s(:Punctuation(:hash)))
						{
							nest_value();
							p.expect_s(:Number(:Normal));
							resume();
						} ELSE {
							nest_type();
							parse_type(p);
							resume();
						}
					} WHILE(p.consume_s(:Punctuation(:semicolon)))
					p.expect_s(:Punctuation(:bracketClose));
					id ::= p.expect_p(:Identifier).Identifier;

					IF(p.match_s(0, :Punctuation(:doubleColon)))
						Out.Code += :ChildScope(id);
					ELSE
						Out.Code += :ChildType(id);
				} ELSE {
					Out.StartGlobal := FALSE;
					parse_type_symbol_child_no_tpl(p);
				}
			}
			}
		:BuiltinType:
		{
			Out.Code += :BuiltinType(p.stype().BuiltinType);
			p.next();

			parse_type_mods(p);
		}
		:AuxKeyword:
			SWITCH(p.stype().AuxKeyword)
			{
			:void:
				Out.Code += :Void;
			:this:
				Out.Code += :ThisType(p.consume_s(:PrefixOrPostfixOp(:exclamationMark)));
			}
		}
	}

	parse_type_symbol_child_no_tpl(p: parser::Parser &) VOID
	{
		id: Identifier;
		DO()
		{
			// TODO: template arguments parsing.
			id := p.expect_p(:Identifier).Identifier;
		} FOR(p.consume_s(:Punctuation(:doubleColon)); Out.Code += :ChildScope(id))
		Out.Code += :ChildType(id);
	}
}