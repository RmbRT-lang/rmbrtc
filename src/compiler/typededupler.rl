
::rlc::compiler::typededup {

	ENUM Indirection {

	}

	Modifier {
		Indirection: ir::Indirection;
		Qualifier: ir::Qualifier;
	}

	(/ Example:

		std::io::File
			start: (Surrounding scope)
			code: LookupChildScope(std).LookupChildScope(io).LookupType(File)

		std::[INT]Vector
			start: (Surrounding scope)
			code: LookupChildScope(std).LookupChildType(Vector).InstantiateTemplate(0)
			ctx.0: BuiltinType(INT)

		::std::[INT]Vector
			start: (root scope)
			code: LookupChildScope(std).LookupChildType(Vector).InstantiateTemplate(0)
			ctx.0: BuiltinType(INT)

		std::[std::[INT]Vector]Vector
			start: (Surrounding scope)
			code: LookupChildScope(std).LookupChildType(Vector).InstantiateTemplate(0)
			ctx.0: LookupChildScope(std).LookupChildType(Vector).InstantiateTemplate(1)
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

	// For final types, use a prefix tree? With an U2 id into the nodes.
	// But not all nodes appear as actually instantiated types in the final program, so they might not receive a final runtime type ID. --> We need a deduplicator like with global to file-local IDs.
	UNION ByteCode {
		BuiltinType: tok::BuiltinType;
		TemplateType: U2; // Idx of template in surrounding context? (T)
		TypeId: U2; // globally deduplicated type. Also for classes, etc.?
		ExpandedTemplateTypes: U2; // Idx of template pack, expand it. (Args...)
		LookupChildType: Identifier;
		LookupChildScope: Identifier;
		InstantiateTemplate: U2; // Idx of template arguments to apply to the bytecode.
		Modifier: typededup::Modifier;
	}

	// We want to have a minimal working set in the cache. A prefix tree might unnecessarily fragment the memory or make use touch unnecessarily many cachelines. It might turn out that a deduplicated type ID and a hashmap for deduplicating type encodings is sufficient.
	TypePrefixTree {
		Node: ByteCode; // Actually known from context.
		ID: U2;
		Children: TypePrefixTree *[TABLE ENUM ByteCode];
	}

	TypeDescriptor {
		Code: ByteCode[#]; // Restriction: cannot contain TemplateType or InstnatiateTemplate.
	}

	Context {
	}
}

::rlc::compiler IdDeDupler
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

	{}:
		Alloc := :custom(1024 * 1024, 1024 * 1024),
		IdHashes := :reserve(60000),
		Identifiers := :reserve(60000),
		IdToks := :reserve(60000)
	{
		RootScope.Entries.reserve(1<<16);
	}

	STATIC name() CHAR#[#] -- := "type deduplicator";

	handle_job(in: Input &, out: Output *) VOID
	{
	}
}