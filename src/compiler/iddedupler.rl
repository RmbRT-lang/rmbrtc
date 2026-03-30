INCLUDE "../scoper/scope.rl"
INCLUDE "../parser/parser.rl"

::rlc::compiler IdDeDupler
{
	Output {
		Tokens: @(CACHELINE) tok::FileTokenView;
		LocalIds: U2;
		File: src::File;
		// TODO: Do we want to pass the lookup of local to global IDs / global to local? Actually, we would want this at a later stage, probably.
	}

	Input {
		Tokens: @(CACHELINE) tok::FileTokenView;
		File: src::File;
	}

	// Parser stack and temporaries.
	PRIVATE Alloc: std::temp::Alloc;

	// The global rootscope.
	PRIVATE RootScope: scoper::Namespace;

	{}:
		Alloc := :custom(1024 * 1024, 1024 * 1024),
		IdHashes := :reserve(60000),
		Identifiers := :reserve(60000),
		IdToks := :reserve(60000)
	{
		RootScope.Entries.reserve(1<<16);
	}

	STATIC name() CHAR#[#] -- := "code preparser";

	GlobalIds: U2-std::Vec;
	LocalIds: U2-std::Vec;

	Identifiers: CHAR#[#] -std::Vec;
	IdHashes:    U8       -std::Vec;
	
	IdToks: U4-std::Vec;

	handle_job(in: Input &, out: Output *) VOID
	{
		Identifiers.clear_reuse();
		IdHashes.clear_reuse();
		IdToks.clear_reuse();
		IdToks.reserve(##in.Tokens);

		{
			hots ::= in.Tokens.Hots![];
			ids ::= IdToks![];
			idcount ::= 0;
			FOR(in.Tokens.Hots[FOR ##in.Tokens])
			{
				ids[idcount] := IOTA;
				idcount += (IT.Type == :Identifier);
			}
			IdToks.set_size_ok(idcount);
		}

		Identifiers.clear_reuse();
		Identifiers.reserve(##IdToks);
		IdHashes.clear_reuse();
		IdHashes.reserve(##IdToks);

		{
			f ::= in.File;

			positions ::= in.Tokens.Positions![];
			payloads ::= in.Tokens.Payloads![];
			FOR(IdToks!)
			{
				idtok_i ::= IT;
				tokPos ::= positions[IT].Pos;
				tokLen ::= positions[IT].Length;
				str ::= <src::Span>(tokPos.byte(), tokLen).contents(f);
				Identifiers![][IOTA] := str;

				hash ::= std::hash_str(str);
				IdHashes![][IOTA] := hash;
			}
			Identifiers.set_size_ok(##IdToks);
			IdHashes.set_size_ok(##IdToks);
		}



		GlobalIds.clear_reuse();


		// consolidate file-local identifiers into global list.
		// TODO: test whether it is faster to do the global dedup first, and then construct the file-local ID list from that. After all, one dedup could be faster than two. And the file-local ID list would be much cheaper to create if we already have the global deduplication. The question would just be whether many global lookups would be much worse on cache and therefore be slower. But for now it is not a bottleneck.
		GlobalIds.resize_bare(##Identifiers);
		{
			// deduplicate all identifiers.
			count ::= ##Identifiers & ~3;
			FOR(i ::= 0; i < count; i += 4)
				rlc::ident::[#4]multi_dedup(
					IdHashes![][FROM i],
					Identifiers![][FROM i],
					GlobalIds![][FROM i]);

			FOR(i ::= count; i < ##Identifiers; i++)
				rlc::ident::[#1]multi_dedup(
					IdHashes![][FROM i],
					Identifiers![][FROM i],
					GlobalIds![][FROM i]);

			// Prepare lookup table for deduplicating file-local IDs.
			LocalIds.clear_reuse();
			LocalIds.reserve(1<<16);
			LocalIds.resize(##ident::strings);
			next_local_id: U2 := 1;

			// Store all global identifiers.
			// Store all file-local identifiers.
			hots ::= in.Tokens.Hots![];
			payloads ::= in.Tokens.Payloads![];
			FOR(IdToks!)
			{
				global_ident ::= GlobalIds[:ok(IOTA)];
				hots[IT].SType.Identifier := global_ident;

				local_id_p: U2 * := &LocalIds[:ok(global_ident)];
				local_id ::= *local_id_p;
				fresh ::= local_id == 0;
				local_id := fresh ?? next_local_id : local_id;
				next_local_id += fresh;
				*local_id_p := local_id;
				payloads[IT].Identifier.FileLocal := local_id-1;
			}
			out->LocalIds := next_local_id-1;
		}

		out->File := in.File;
		out->Tokens := in.Tokens;
	}
}