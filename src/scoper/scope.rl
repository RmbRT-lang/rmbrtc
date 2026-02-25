INCLUDE "../identifierPool.rl"
::rlc::scoper
{
	// Actually, it seems like all of these are also potentially valid namespaces.
	ENUM NonValueGlobal
	{
	*	Nil,
	?	Namespace,
	?	Class,
	?	Rawtype,
	?	Typedef,
	?	Mask,
	?	Union,
	?	Enum
	}

	ENUM ValueGlobal
	{
	*	Nil,
	?	Function,
	?	ExportFunction,
	?	ExternFunction,
	?	Variable,
	?	ExportVariable,
	?	ExternVariable
	}

	Namespace
	{
		Entry
		{
			// We use fat pointers so that we can sort the looked-up value into a work queue without having to chase another pointer.

			Name: U2; // For quick patching/restoring of LUTs.
			NVType: NonValueGlobal;
			VType: ValueGlobal;

			NVMem: MemID;
			VMem: MemID;


			{name: rlc::Identifier}:
				NVType := :Nil,
				VType := :Nil,
				Name := name,
				NVMem(NOINIT),
				VMem(NOINIT);

			set_vtype(type: ValueGlobal, name: Identifier, at: U4, p: parser::Parser &) VOID -- {
				IF(VType != :Nil)
					term::error(p.at_pos(at).at(), "Re-definition of ", ident::get(name), " as ", std::str::enum(type), " (already exists as ", std::str::enum(VType), ")");
				VType := type;
				//term::info(at.at(), std::str::enum(type), " ", ident::get(name));
			}
			set_nvtype(type: NonValueGlobal, name: Identifier, at: U4, p: parser::Parser &) VOID -- {
				IF(NVType != :Nil)
					term::error(p.at_pos(at).at(), "Re-definition of ", ident::get(name), " as ", std::str::enum(type), " (already exists as ", std::str::enum(NVType), ")");
				NVType := type;
				//term::info(at.at(), std::str::enum(type), " ", ident::get(name));
			}
		}

		// Every namespace has a 64K LUT or something. It's not that frequently incurred, and they are the most frequent thing that lookups happen in.
		// Functions and classes etc. have a lookup based on per-file Identifier IDs during parse time. Lookups from the inside are always in per-file IDs, while lookups from the outside are in global IDs. We could also say that we use a 64K buffer per file to translate from global to per-file IDs, which would help with LUT sizes in classes, etc. But namespaces still need the full 64K space because they do not belong to a single file. But with this, we can use smaller tables for insider lookups, which is less work per function.
		// We need some system for efficiently creating and reusing identifier LUTs, so that small functions do not spend much time on crap. Maybe we can decide after parsing the function whether we need a LUT (by counting number of variables & arguments) or whether a simple linear search would beat the cost of creating a LUT.
		// Each lookup of an identifier is at least one branch miss per scope traversal, unless we lookup multiple scopes in parallel and do it branchless. But having a depth > 1 means we also have a loop and therefore a branch miss. If we can guarantee to only have one scope to look at, then we are guaranteed to save on the branch miss, and to look up one per cycle. So we get a massive latency and throughput gain, with up to two lookups per cycle, theoretically.
		// We could outsource the allocation and preparation of the LUTs to separate threads, which could hide the cost of using LUTs by just preparing 0-initialised buffers for the pre-parser to use (this can happen during file loading, etc., for free), and also by preparing the various copied scopes for the post-parser. Then each namespace could have 4 copies that the post-parser can use simultaneously, parsing up to 4 functions at once. ??? - we could also use a 64K per-function scratchpad to deduplicate identifiers, so that we only need to gather the lookups of all identifiers that appear within a function. We can then clear that scratchpad easily again by looping over the deduplicated list of identifiers. So we can have per-file deduplicators, and then also per-local-scope deduplicators that progressively shrink in size. --> sketch it all out and estimate the costs and performance of various approaches.
		// ---> Each file should have a LUT for looking up first-class identifiers (names of defined symbols, not containing names that refer to other things). Each class then refers to its file's LUT, and per class, we only need LUTs that are as the number of symbols that get defined in the file. While this adds indirection, it is still a constant-depth indirection and we can still look up many things in parallel even in the presence of cache misses. So _.x would be "x" -> fileof(typeof(_))."x", typeof(_)."x". This would be a lookup of the type, which is needed anyway, then a lookup in the file's LUT (pointer to which can be saved on the type to avoid one more indirection & touched cacheline), and then a lookup on the type's member LUT, and then a final memory resolve. type lookup, two chained ID LUTs, and the final memory LUT. This allows for overall much smaller memory footprint, better cacheline utilisation per file, less setup work. A file could also differentiate between symbols defined that could be reached from the outside vs. from the inside. With 4 chained memory lookups, we can easily parallelise this, and with contextual locality of references, we also should get a good cache hit rate, and misses should be amortised well, with at least 8 sustainable parallel lookup steps being possible even for LLC misses. With small identifier sets per file, we can also maintain fully resolved sets per scope. Scopes can also have such deduplicated identifier sets. Also, we should differentiate between identifiers that are member lookups (_.x) vs. identifiers that are scope entry lookups (x._). member lookups are always based on the object's type, and therefore do not count into the set of identifiers we want to cache into the lookup for first-order lookups.
		Lut: Entry-Handle[]; // Full-size mapping for all identifiers.
		Exists: U1 [];
		Entries: Entry-Handle -std::Vec;

		{}:
			Lut := std::heap::alloc.[Entry-Handle]alloc_array(1<<16),
			Exists := std::heap::alloc.[U1]alloc_array((1<<16) / 8),
			Entries := :reserve(256)
		{
			exists_u8 ::= <U8 *>(<VOID *>(Exists))[FOR (1<<16) / 64];
			FOR(exists_u8) IT := 0;
		}

		ensure(id: rlc::Identifier) Entry-Handle
		{
			entry ::= Lut[id];
			IF!(Exists[id >> 3] & (1 << (id & 7)))
			{
				Exists[id >> 3] |= (1 << (id & 7));
				e ::= mempool::[Entry]alloc_unhashed_t();
				e.(0)->{id};
				entry := e.(1);
				Lut[id] := entry;
			}
			= entry;
		}

		# lookup(id: rlc::Identifier) Entry-Handle -- := Lut[id];

		[#N]
		# multi_lookup(id: rlc::Identifier#[], out: Entry-Handle []) VOID
		{
			FOR(N)
				out[IOTA] := lookup(id[IOTA]);
		}
		[#N]
		STATIC lookup_bulk(ns: Namespace# *#[], id: rlc::Identifier#[], out: Entry-Handle []) VOID --
		{
			FOR(N)
				out[IOTA] := ns[IOTA]->lookup(id[IOTA]);
		}
	}
(/
	GlobalVariable {
		Type: :?;
		InitValue: IRSpan - std::Opt;
	}
	Function {
		ReturnType: :?;
		Code: IRSpan;
	}/)


	(// Use this to look up many things in one single scope, such as locals, or class members & templates.
	@param names:
		An unordered set of names. CAUTION: Must not contain duplicates.
	@param found_index:
		-1 if not found, otherwise, the index of the element. /)
	[#kN]
	find_linear(
		ids_to_find: @(SIMD) Identifier [kN] #&,
		names:               Identifier#[#],
		found_index: @(SIMD) U2         [kN] &) VOID
	{
		|||{ids_to_find}
		{
			search_name ::= IT;
			index: S2 := -1;
			// roughly 3 cycles per iteration, 8 values. Can execute 2-3 iterations simultaneously, probably, so 16-24 SISD iterations every 3 cycles, being 5-8 SISD iterations per cycle.
			FOR(names)
				index ^= MASK(IT == search_name) &~ IOTA;
			found_index[IOTA] := index;
		}
	}
}