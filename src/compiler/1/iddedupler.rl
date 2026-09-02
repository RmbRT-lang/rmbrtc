INCLUDE "../../scoper/scope.rl"
INCLUDE "../../parser/parser.rl"

::rlc::compiler IdDeDupler
{
	Output {
		Tokens: @(CACHELINE) tok::FileTokenView;
		LocalIds: U2;
		File: src::File;
		// TODO: Do we want to pass the lookup of local to global IDs / global to local? Actually, we would want this at a later stage, probably.
		IsDummy: BOOL;
	}

	Input {
		Tokens: @(CACHELINE) tok::FileTokenView;
		File: src::File;
		IsDummy: BOOL;
	}

	{}:
		IdHashes := :reserve(1<<16),
		Identifiers := :reserve(1<<16),
		IdToks := :reserve(1<<16)
	{
	}

	STATIC name() CHAR#[#] -- := "id dedupler";

	GlobalIds: U2-std::Vec;
	LocalIds: U2-std::Vec;

	Identifiers: CHAR#[#] -std::Vec;
	IdHashes:    U8       -std::Vec;
	
	IdToks: U4-std::Vec;

	handle_job(in: Input &, out: Output *, U4) {BOOL, U4}
	{
		Identifiers.clear_reuse();
		IdHashes.clear_reuse();
		IdToks.clear_reuse();
		IdToks.reserve(##in.Tokens);

		{ // make a list of all identifiers.
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

		// NOTE PERFORMANCE: we could make this faster by doing a Sean Barrett style branchless machine that goes over all identifiers for hashing, and also progresses to the next identifier branchlessly. And then one final digest pass over all identifiers. That way, we could eliminate all branch misses from the hashing loop. -- no, it was not faster, due to register spills and more complex setup logic. -- LEARNING: branchless loop processing machines are only viable when they do not spill registers in a way that introduces a loop-carried dependency with a long latency. Maybe we would need actual hand-rolled assembly for that. And in that case, we definitely do need platform-specific assembly, because a generic solution cannot account for differing register counts, etc., on different machines.
		// TODO DESIGN: Can we make a language-level feature for this? Some directive that lets you control which values to keep hot, or where you want to minimise latencies. But then, this would mean we would need a reliable result. We want the guarantee that this code is actually faster, so we need a way to force the compiler to honour this properly during code generation, and to also succeed at the task, or result in a compile error or warning. Which would be quite complex and make the optimiser mandatory. There's also the issue of whether you run an optimised build or not. If certain assembly code is a core feature of the program, then you probably want to hand-write it. But ideally, you still write that assembly in a way that lets the compiler understand it?
		// NOTE DESIGN: We could add a feature for either forcefully spilling a value, or for "touching" a value in the LRU for the registers, ensuring they are in register and marked as recent: TOUCH a,b,c; SPILL a,b,c; And we could also have something that suppresses a value from going into a register, using memory operations if possible. However, then, we basically demand that there will be a LRU implementation for registers, and code reordering would also interfere with that. So we probably want a mode that lets us write code that does not get reordered, where we basically hand-roll assembly. -- Conclusion: I'm not actually sure what exactly I would want from such a feature. But it could certainly be useful to expose some commands for the code generator to the programmer, maybe allowing direct IR commands to be issued. After all, the high level language translates into IR, and only then does it translate to assembly. For some things, we do want the ability to write actual assembly code, and there, it would make most sense to allow direct linking towards object code, or direct pasting thereof. Then we just need a way to communicate with the code generator to tell it about stuff like register clobbering or how to pass values into it.
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

				hash ::= (0) ?? std::hash_str_reference(str) : (1) ?? std::hash_str_weak(str) : std::hash_str(str);
				IdHashes![][IOTA] := hash;
			}
			Identifiers.set_size_ok(##IdToks);
			IdHashes.set_size_ok(##IdToks);
		}



		GlobalIds.clear_reuse();


		// consolidate file-local identifiers into global list.
		// TODO: test whether it is faster to do the global dedup first, and then construct the file-local ID list from that. After all, one dedup could be faster than two. And the file-local ID list would be much cheaper to create if we already have the global deduplication. The question would just be whether many global lookups would be much worse on cache and therefore be slower. But for now it is not a bottleneck. -- it is faster.
		GlobalIds.resize_bare(##Identifiers);
		{
			// deduplicate all identifiers.
			count ::= ##Identifiers & ~7;
			FOR(i ::= 0; i < count; i += 8)
				rlc::ident::[#8]multi_dedup(
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
		out->IsDummy := in.IsDummy;

		= (!in.IsDummy, in.File);
	}
}