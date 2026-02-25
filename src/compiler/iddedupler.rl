INCLUDE "../scoper/scope.rl"
INCLUDE "../parser/parser.rl"

::rlc::compiler IdDeDupler
{
	Output {
		Tokens: @(CACHELINE) tok::FileTokens;
		LocalIds: U2;
		File: src::File;
		// TODO: Do we want to pass the lookup of local to global IDs / global to local? Actually, we would want this at a later stage, probably.
	}

	Input {
		Tokens: @(CACHELINE) tok::FileTokens;
		Identifiers: CHAR#[#] -std::Vec;
		IdHashes:    U8       -std::Vec;
		File: src::File;
	}

	// Parser stack and temporaries.
	PRIVATE Alloc: std::temp::Alloc;

	// The global rootscope.
	PRIVATE RootScope: scoper::Namespace;

	{}:
		Alloc := :custom(1024 * 1024, 1024 * 1024)
	{
		RootScope.Entries.reserve(1<<16);
	}

	STATIC name() CHAR#[#] -- := "code preparser";

	GlobalIds: U2-std::Vec;

	handle_job(in: Input &, out: Output *) VOID
	{
		GlobalIds.clear_reuse();
		GlobalIds.reserve(4096);

		out->LocalIds := ##in.Identifiers;
		out->File := in.File;

		// consolidate file-local identifiers into global list.
		GlobalIds.resize_bare(##in.Identifiers);
		{
			// deduplicate all identifiers.
			count_8 ::= ##in.Identifiers & ~7;
			FOR(i ::= 0; i < count_8; i += 8)
				rlc::ident::[#8]multi_dedup(
					in.IdHashes![][FROM i],
					in.Identifiers![][FROM i],
					GlobalIds![][FROM i]);

			FOR(i ::= count_8; i < ##in.Identifiers; i++)
				rlc::ident::[#1]multi_dedup(
					in.IdHashes![][FROM i],
					in.Identifiers![][FROM i],
					GlobalIds![][FROM i]);

			// Store all global identifiers.
			FOR(in.Tokens.Hots!)
			{
				local_id ::= IT.SType.Identifier;
				local_id := local_id < ##GlobalIds ?? local_id : 0;
				payload ::= in.Tokens.Payloads[:ok(IOTA)].Identifier.Global;
				global_ident ::= GlobalIds[:ok(local_id)];
				payload := (IT.Type == :Identifier) ?? global_ident : payload;
				in.Tokens.Payloads[:ok(IOTA)].Identifier.Global := payload;
			}
		}

		// in.Tokens :=: out->Tokens;
			tmp ::= &&out->Tokens;
			out->Tokens := &&in.Tokens;
			in.Tokens := &&tmp;

	}
}