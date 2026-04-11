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

	ENUM Indirection {
		Reference,
		Pointer,
		NonNull,
		SizedSlice,
		UnsizedSlice,
		Atomic, // maybe this should be a qualifier instead?
		Future
	}

	ENUM Qualifier {
		Const,
		MaybeConst,
		Shared
	}

	ENUM Constness {
		Mutable,
		Const,
		MaybeConst
	}
	ENUM Sharedness {
		Unique,
		Shared
	}

	Qualifier { // NOTE: Could be compressed to 3 bits.
		Const: Constness;
		Shared: Sharedness;
	}

	Modifier {
		Indirection: ir::Indirection;
		Qualifier: ir::Qualifier;
	}

	(/ Example:

		std::io::File
			start: (Surrounding scope)
			code: LookupScope(std).LookupScope(io).LookupType(File)

		std::[INT]Vector
			start: (Surrounding scope)
			code: LookupScope(std).LookupType(Vector).InstantiateTemplate(0)
			ctx.0: BuiltinType(INT)

		::std::[INT]Vector
			start: (root scope)
			code: LookupScope(std).LookupType(Vector).InstantiateTemplate(0)
			ctx.0: BuiltinType(INT)

		std::[std::[INT]Vector]Vector
			start: (Surrounding scope)
			code: LookupScope(std).LookupType(Vector).InstantiateTemplate(0)
			ctx.0: LookupScope(std).LookupType(Vector).InstantiateTemplate(1)
			ctx.1: BuiltinType(INT)
	/)


	PerScopeLookupRequestBatch {
		Start: Scope *;
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

	// Something that a bytecode operation is performed on. We want to batch processing based on value type and operation. Also, if we batch based on that, we also do not need to store the value tag.
	// TODO: How do we unify this with values and code generation?
	UNION TypeCore { // IMPORTANT: keep below 32 entries.
		BuiltinType: tok::BuiltinType; // U1 etc.
		Void;
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
		MaybePointer;
		Array;
		AutoArray;
		Table;
		Slice;
		SizedSlice;
		Atomic; // TODO: Do we want this as a qualifier or as an indirection? Ideally, we want to allow non-atomic writes and reads for atomic values (such as for memcpy when we are the current owner). Actually, atomic is a level of sharedness? But INT.[?] is not INT[?]., because we do need to be clear on what piece of data has to be atomically updated. I think for now, we should only allow atomics on primitive types and pointers. If we have atomics here, we can leverage them into their own SWITCH case, without having to do manual IFs for checking the flag.

		TupleType;
		FnSigType;
	}

	// We want TypeCore + TypeMod[]. TypeCore contains the atoms, like user types, builtins, and symbol types. TypeMod contains arrays and other things that composit over types.
	UNION TypeMod {
	}

	// Additional data for a type.
	TypeMeta { // NOTE: could be compressed to one byte (6 bits).
		Qualifier: typededup::Qualifier; // 3
		Lifetime: ir::Lifetime;          // 3
	}

	// For final types, use a prefix tree? With an U2 id into the nodes.
	// But not all nodes appear as actually instantiated types in the final program, so they might not receive a final runtime type ID. --> We need a deduplicator like with global to file-local IDs.
	UNION ByteCode {
		MakeTuple: U2; // number of tuple elements.
		MakeFnSig: U2; // number of arguments.
		MakeTemplateSymbolType: Identifier;
		ExpandTemplateTypes: U2; // Idx of template pack, expand it. (Args...)
		LookupType: Identifier;
		LookupScope: Identifier;
		InstantiateTemplate: U2; // Idx of template arguments to apply to the bytecode.
		AddModifier: typededup::Modifier; // when adding any modifiers.
		MakeAutoArray;
		MakeArray;
		MakeTable;
		MakePointer;
		Dereference; // element of pointer or array, or result of *THIS/THIS-> operator.
		GetUnionTag;
		MakeTaggedUnion;
		TupleFieldAccess: U2; // .(Index)
		FieldAccess: U2; // .(:Field)
	}

	FullState { // NOTE: could be compressed to just 4 bytes:
		Meta: TypeMeta;          // 1 byte      | 6 bits
		Kind: ENUM TypeCore;     // 1 byte      | 5 bits = 11
		//                          1 byte free | 5 bits = 16, could be used for extra tag.
		Core: typedup::TypeCore; // 2 bytes
	}

	PackedExtendedState {
		Bits: U4;
		Extra: ExtraTypeInfo;

		# kind() ENUM TypeCore := >(Bits & 31);
		set0_kind(v: ENUM TypeCore) VOID -- := Bits |= <U4>(v);

		# constness() Constness -- := >(Bits >> 5 & 3);
		set0_constness(v: Constness) VOID -- := Bits |= <U4>(v) << 5;

		# sharedness() Sharedness -- := >(Bits >> 7 & 1);
		set0_kind(v: Sharedness) VOID -- := Bits |= <U4>(v) << 7;

		# lifetime() ir::Lifetime -- := >(Bits >> 8 & 7);
		set0_lifetime(v: ir::Lifetime) VOID -- := Bits |= <U4>(v) << 8;

		# extra_tag() ExtraTypeInfoTag -- := :Raw(Bits >> 11); // & 31 implicit.
		set0_extra_tag(v: ExtraTypeInfoTag) VOID -- := Bits |= <U4>(v.Raw) << 11;
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

	FixedType {
		Stages: FullState[#];
		AdditionalInfo: ExtraTypeInfo[#];
	}

	LiveType {
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

	Out: LiveType;

	Current: U4;
	Starts: U4-std::Vec; // starting location of unfinished types.

	start() VOID -- { Starts += Current; }
	finish_type() VOID -- {
		Starts.pop_back(&Current);
	}

	parse_type(p: Parser &) VOID
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
						IF(p.consume(:Punctuation(:hash)))
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
						Out.Code += :LookupScope(id);
					ELSE
						Out.Code += :LookupType(id);
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
			{
				Out.Code += :Void;
			}
			:this:
			{
				x ::= p.consume_s(:PrefixOrPostfixOperator(:exclamationMark));
				add: TAGGED TypeCore := :This;
				add.(0) := WHEN(x) ThisNoDecay;
				Out.Code += add;
			}
			}
		}
	}

	parse_type_symbol_child_no_tpl(p: Parser &) VOID
	{
		id: Identifier;
		DO()
		{
			// TODO: template arguments parsing.
			id := p.expect_p(:Identifier).Identifier;
		} FOR(p.consume_s(:Punctuation(:doubleColon)); out.Code += :LookupScope(id))
		out.Code += :LookupType(id);
	}
}