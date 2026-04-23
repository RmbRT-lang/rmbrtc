INCLUDE "../identifierPool.rl"
INCLUDE "../mempool.rl"
::rlc::scoper
{
	UNION NVGlobal {
	*	Nil:       MemID;
	?	Namespace: scoper::Namespace -Handle;
	?	Class:     parser::Class     -Handle;
	?	Rawtype:   parser::Rawtype   -Handle;
	?	Typedef:   parser::Typedef   -Handle;
	?	Mask:      parser::Mask      -Handle;
	?	Union:     parser::Union     -Handle;
	?	Enum:      parser::Enum      -Handle;
	}
	UNION VGlobal {
	*	Nil:            MemID;
	?	Function:       parser::Function       -Handle;
	?	ExportFunction: parser::ExportFunction -Handle;
	?	ExternFunction: parser::ExternFunction -Handle;
	?	Variable:       parser::GlobalVariable -Handle;
	?	ExportVariable: parser::ExportVariable -Handle;
	?	ExternVariable: parser::ExternVariable -Handle;
	}
	Namespace
	{

		// We use fat pointers so that we can sort the looked-up value into a work queue without having to chase another pointer.
		NVEntry {
			Type: ENUM NVGlobal;
			Mem: NVGlobal;
		}

		VEntry {
			Type: ENUM VGlobal;
			Mem: VGlobal;
		}

		Entry
		{
			NonValue: NVEntry;
			Value: VEntry;

			set_value(
				v: TAGGED VGlobal,
				name: Identifier,
				at: U4,
				p: parser::Parser &) VOID --
			{
				type ::= v.(0); id ::= v.(1);
				IF(Value.Type != :Nil)
					term::error(p.at_pos(at).at(), "Re-definition of ", ident::get(name), " as ", std::str::enum(type), " (already exists as ", std::str::enum(Value.Type), ")");
				Value.Type := type;
				Value.Mem := id;
				//term::info(at.at(), std::str::enum(type), " ", ident::get(name));
			}
			set_nonvalue(
				v: TAGGED NVGlobal,
				name: Identifier,
				at: U4,
				p: parser::Parser &) VOID --
			{
				type ::= v.(0); id ::= v.(1);
				IF(NonValue.Type != :Nil)
					term::error(p.at_pos(at).at(), "Re-definition of ", ident::get(name), " as ", std::str::enum(type), " (already exists as ", std::str::enum(NonValue.Type), ")");
				NonValue.Type := type;
				NonValue.Mem := id;
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
		Entries: {U2, Entry-Handle} -std::Vec;
		Namespaces: {U2, Namespace-Handle}-std::Vec;

		// Full-size mapping for all identifiers. For relative lookups from inside the namespace. We have split this into two because we only want to look up one at a time. We could also use a fused entry like the other lookup table, though. We could also use duplicate Entries or something, and follow the same structure as Lut. However, the Lut only has that indirection because we want to save on pointer sizes due to the massive, sparse, 64K overallocation. These however are not overallocated, although still sparse. Ideally, we would also use a version of this for an OuterLut, and then simply throw away Lut. That way, we could also unify namespace and member scopes again, maybe? Although we have to differentiate anyway since members use a different identifier for their lookups.
		InnerLutV: VEntry[];
		InnerLutNV: NVEntry[];
		{}:
			Lut := std::heap::alloc.[Entry-Handle]alloc_array(1<<16),
			Exists := std::heap::alloc.[U1]alloc_array((1<<16) / 8),
			Entries := :reserve(256),
			Namespaces := :reserve(128)
		{
			exists_u8 ::= <U8 *>(<VOID *>(Exists))[FOR (1<<16) / 64];
			FOR(exists_u8) IT := 0;
		}

		ensure(_id: rlc::GlobalDeclIdentifier) Entry-Handle
		{
			id ::= _id.V;
			entry ::= Lut[id];
			IF!(Exists[id >> 3] & (1 << (id & 7)))
			{
				Exists[id >> 3] |= (1 << (id & 7));
				e ::= mempool::[Entry]alloc_unhashed_t();
				e.(0)->{};
				entry := e.(1);
				Lut[id] := entry;
				Entries += (id, entry);
			}
			= entry;
		}

		# lookup(id: rlc::GlobalDeclIdentifier) Entry-Handle -- := Lut[id.V];
		# entry_addr(id: rlc::GlobalDeclIdentifier) Entry-Handle * -- := &Lut[id.V];

		[#N]
		# multi_lookup(id: rlc::GlobalDeclIdentifier#[], out: Entry-Handle []) VOID
		{
			FOR(N)
				out[IOTA] := lookup(id[IOTA]);
		}
		[#N]
		STATIC lookup_bulk(ns: Namespace# *#[], id: rlc::GlobalDeclIdentifier#[], out: Entry-Handle []) VOID --
		{
			FOR(N)
				out[IOTA] := ns[IOTA]->lookup(id[IOTA]);
		}







		// The preparser can do some more free work. We can use it to deduplicate identifiers for global declarations. That way, namespaces need way smaller tables. Additionally or alternatively, we may want to look at a more compact scheme for the tables. The Global -> Decl identifier tables are reasonably small and will be hot in cache for the name lookup stage. We could additionally enhance tables with blooms, though then it also becomes annoying to do insertions and lookups, maybe. Though the extra popcount would be amortised down to basically nothing.















		// Only call this after all parsing is finished. It allows us to look up an identifier from within a nested scope with a single operation. Also 0-initialises the previously unset fields in Lut. This makes it safe to look up members without checking for Exists.
		// NOTE PERFOMANCE: complexity is ##namespaces * ##idents, but it gives us much faster and simpler (loopless, branchless) scope-relative lookups for all identifiers.
		post_process_1(outerLutV: VEntry#[], outerLutNV: NVEntry#[]) VOID
		{
			cap ::= ident::GlobalDeclCount;
			STATIC t_alloc_i: std::temp::Alloc := :custom(16 * MI, 16 * MI);
			STATIC t_alloc: std::temp::Alloc-std::AllocPimpl-std::Alloc := <std::temp::Alloc-std::AllocPimpl>(&t_alloc_i);

			STATIC nv_entries: {U2, NVEntry #*}-std::Vec := :reserve(16<<10);
			nv_entries.clear_reuse();
			nv_entries.reserve(##Entries);

			STATIC v_entries: {U2, VEntry #*}-std::Vec := :reserve(16<<10);
			v_entries.clear_reuse();
			v_entries.reserve(##Entries);

			PREFETCH_READ Namespaces.data();

			{
				nv_ptr ::= nv_entries![];
				v_ptr ::= v_entries![];
				nv_count ::= 0;
				v_count ::= 0;

				FOR(Entries!)
				{
					entry ::= IT.(1).get();
					v_ptr[v_count] := (IT.(0), &entry->Value);
					nv_ptr[nv_count] := (IT.(0), &entry->NonValue);
					v_count += <BOOL>(entry->Value.Type);
					nv_count += <BOOL>(entry->NonValue.Type);
				}

				v_entries.set_size_ok(v_count);
				nv_entries.set_size_ok(nv_count);
			}

			// NOTE PERFORMANCE: this currently writes almost a megabyte (765KiB) of memory in total (50 namespaces, 1568 IDs), taking around 0.700ms to run. To write a megabyte, we should not take longer than 0.250ms or 0.150ms. So we should be able to go around 4x faster. This takes up 7% of the budget, or 50% overhead of phase 1. We could reduce it to 1.5%, and if we intelligently used multiple threads, we could cut that by half once more, probably. Though since we have to traverse a tree breadth-first, root-first, parallelising this properly could be a bit tricky.
			// I hope this pays off properly when we start resolving names.
			// -- Got it down to 0.100ms, or 1.1% of the budget. We can optimise it more later.

			// TODO PERFORMANCE: have one big pool of ##namespaces * ##idents somewhere.
			innerLutV ::= t_alloc.[VEntry]alloc_array(cap)[];
			innerLutNV ::= t_alloc.[NVEntry]alloc_array(cap)[];
			InnerLutV := innerLutV;
			InnerLutNV := innerLutNV;

			// If we had the guarantee that it is already 0-initialised, then we would not have to deal with it. But then we also wouldn't need Exists to begin with. TODO: we want to have an allocator that is guaranteed to 0-initialise, via mmap().
			IF(1)FOR(cap) // NOTE PERFORMANCE: This loop takes up around 0.1ms already.
			{
				handle ::= Lut[IOTA];
				exists: BOOL := Exists[IOTA >> 3] & (1 << (IOTA & 7));
				handle := exists ?? handle : <Entry-Handle>(0);
				Lut[IOTA] := handle;
			}

			IF(outerLutV)
			{
				//NOTE PERFORMANCE: if everything else is disabled, this costs 0.3ms. However, with the other loops enabled, this only has a cost of 0.04ms. So we know for sure that the main cost of our algorithm is the cache misses. However, the outerLut should be still in cache when we use it, most of the time, maybe. Although going through multiple tree levels would probably evict it. However, it should still be in L3 cache even then, so we should not be bandwidth-limited here, and the LUTs fit into L3. Though we might be unable to use it fully. It would be better to go breadth-first instead of depth-first, I think.

				// Inherit the relative lookup of the parent.
				IF(1) // NOTE PERFORMANCE: This was worth 0.1ms.
				{
					std::mem::cpy_array(innerLutV[], outerLutV, cap);
					std::mem::cpy_array(innerLutNV[], outerLutNV, cap);
				} ELSE
				{
					FOR(cap) innerLutV[IOTA] := outerLutV[IOTA];
					FOR(cap) innerLutNV[IOTA] := outerLutNV[IOTA];
				}
			} ELSE IF(1) // NOTE PERFORMANCE: not really measurable since this is only 1/50th of the cases (only the root scope).
			{
				FOR(cap) innerLutV[IOTA].{};
				FOR(cap) innerLutNV[IOTA].{};
			}

			// TODO PERFORMANCE: We could also make it so that we first create all the scopes, rely on 0-init, and then do a sparse fill for all^^ transitive children, instead of brute-forcing the work we do by fully writing the sparse sets.

			// Override the shadowed lookups.
			FOR(v_entries!) // NOTE PERFORMANCE: almost unmeasurable if we turn it off. However, if we turn off the memcpy, then we lose all the performance. This means we get too many cache misses. We reach around 2GiB of write speeds for this.
			{
				entry ::= IT.(1);
				innerLutV[IT.(0)] := *entry;
			}

			FOR(nv_entries!)
			{
				entry ::= IT.(1);
				innerLutNV[IT.(0)] := *entry;
			}
		}

		// This step recurses into the
		post_process_2() VOID
		{
			IF(Namespaces)
			{
				// Placebo optimisation, but it breaks the dependency chain up a bit.
				{
					i ::= 0;
					entry ::= Namespaces![][i].(1).get();
					PREFETCH_READ entry->Namespaces.data();
					PREFETCH_READ entry->Entries.data();
					WHILE(++i != ##Namespaces) {
						next ::= Namespaces![][i].(1).get();
						PREFETCH_READ next;
						old ::= entry;
						entry := next;
						old->post_process_1(InnerLutV, InnerLutNV);
					}
					entry->post_process_1(InnerLutV, InnerLutNV);
				}

				{
					i ::= 0;
					entry ::= Namespaces![][i].(1).get();
					WHILE(++i != ##Namespaces) {
						next ::= Namespaces![][i].(1).get();
						PREFETCH_READ next;
						old ::= entry;
						entry := next;
						old->post_process_2();
					}
					entry->post_process_2();
				}
			}
		}

		# lookup_inner_v(id: GlobalDeclIdentifier) VEntry *-- {
			entry ::= &InnerLutV[id.V];
			= entry->Type ?? entry : NULL;
		}
		# lookup_inner_t(id: GlobalDeclIdentifier) NVEntry * -- := InnerLutNV[id.V].Type ?? &InnerLutNV[id.V] : NULL;

		# lookup_t(id: GlobalDeclIdentifier) Entry * -- {
			handle ::= Lut[id.V];
			IF!(handle) term::error(HERE, "No such symbol. TODO: better message");
			entry ::= handle.get();

			= (1 << <U1>(entry->NonValue.Type) & ~NVGlobal::FLAGS(:Nil, :Namespace))
				?? entry
				:  NULL;
		}
		# lookup_v(id: GlobalDeclIdentifier) Entry *-- {
			handle ::= lookup(id);
			IF!(handle) term::error(HERE, "No such symbol. TODO: better message");
			entry ::= handle.get();
			= entry->Value.Type ?? entry : NULL;
		}
		# lookup_s(id: GlobalDeclIdentifier) Entry *-- {
			handle ::= lookup(id);
			IF!(handle) term::error(HERE, "No such symbol. TODO: better message");
			entry ::= handle.get();

			= entry->NonValue.Type ?? entry : NULL;
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
}