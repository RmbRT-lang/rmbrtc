
INCLUDE 'std/memory'
INCLUDE 'std/vector'

(// Identifiers:

	rlc::Identifier - Globally deduplicated identifiers. These are used to look up things in the global scope and in namespaces. There can be up to 64Ki distinct identifiers in a program.
	rlc::FileLocalIdentifier - per-file deduplication of identifiers, so that we have a small size for file-wide lookup tables. This is used to look up things from within function bodies and expressions.
	rlc::FileDeclIdentifier - only the set of names of publicly reachable declarations in the file, such as members. This lets us have tiny lookup tables for members, keeping classes and enums, etc. compact. Each file contains a lookup table to map global identifiers into these.
/)

// 0 is invalid / none.
::rlc Identifier { V: U2; }
::rlc FileLocalIdentifier { V: U2; }
::rlc FileDeclIdentifier { V: U2; }
::rlc GlobalDeclIdentifier { V: U2; }

(/
Looking up a namespace member:
	namespace.LUT[Identifier]
	- fast and simple, but namespaces have pessimistic sizes.
		- We could also have GlobalDeclIdentifier to reduce namespace sizes, but for now, it should be sufficient to keep it as is.
	- low register pressure and minimal instruction complexity for high parallelisability.

Looking up a member in a member scope:
	scope.LUT[ scope.File->DeclLut[Identifier] ]
	- or: scope.LUT[ scope.FileDeclLut[Identifier] ], which would reduce pointer chasing.
	- One indirection on the index, but cuts down on member scope sizes and keeps register pressure low.
	- High throughput.

Looking up a member in a local scope:
	???

	- We probably want to use a LUT[FileLocalIdentifier] here.
	- We want to first assemble this LUT for the global scope, and look up all possible names.
	- When entering a nested scope, we want to override entries in the LUT with all values in that scope.
		- We might want to have a pre-baked namespace.CtxLUT[Identifier], which we can directly query. This way, we can work on all namespaces in a file in parallel, as we no longer need patching. We can create one LUT[FileLocalIdentifier] per namespace that has declarations in the file.
			- We need to track the list of namespaces having definitions in a file.
	- Inside local scopes, we need patching and unpatching or something, or we separately maintain a scope for local references. We can actually resolve local references first, and only afterwards look up references that are not local. That way, we have the static/baked per-namespace or per-class .CtxLUT[] scopes, and one temporary scope per function which is modified as we traverse through the AST, and then discarded.

	- How do we parallelise/batch identifier lookups? We somehow need parallelism from the serial parse. Parsing multiple expressions in parallel seems tough, as it is branchy logic. Unless we can fully statemachine-drive the parsing and have multiple interleaved parses on one thread.
		- During the parsing of an expression (a + b), when reading the (+), we cannot yet emit code anyway, since we do not yet know what is to follow. So we kind of end up with a reverse polish notation / stack of operands and operations. When encountering an identifier, we can queue it for batch lookup. When encountering an operator, we can queue it into the IR / type checker. After resolving all identifiers, we then only have to go through the type checker and pop values off the reverse polish notation argument stack. This could also be made branchless, maybe, or cached with a predictable path for cached types.
			- We need to look up all queued identifiers whenever a variable gets declared, and then update the LocalLUT[FileLocalIdentifier]. But between declarations, all other references can be batched. So we can still get adequate batching in many situations. OR: we might look up the name in the current and parent localscope and then check its position to decide which value to look up. This ensures only one resolve pass per scope, but it requires nested scope LUTs. We could circumvent this by going through all identifiers in a scope and deduplicating them first or something, but this might defeat the purpose and simplicity of the whole endeavour. So I would rather stick to the initial plan, and that also seems less error-prone to implement.
				- Although we need to do identifier resolves in multiple passes, we should end up with one linear stream of RPN instructions for an entire function. We can segment that stream into per-statement spans, so that we can try to interleave the work done on multiple statements.
					- Before processing a statement's operations, we need to ensure all knowable variable types are already resolved. If we encounter an unresolvable variable (e.g., auto variable making an auto function call, templates), only then should special handling occur.
					- Instructions or expressions that depend on a templated operand need to be processed separately.
			- During processing/checking/code generation, we want to be able to already know whether something is a definite last use of a variable or not, and we already want to have resolved destructors (especially, whether they are nops or not). Ideally, we only need to patch placeholders for labels, and be able to directly allocate registers on the fly, to achieve reasonable O0 performance.

	- Notice that local symbols can only be variables. All type references must necessarily refer to member types or global types or templates.
/)

::rlc::ident
{

	// Big global hashmap with 4Ki buckets (12 bit selector), and 10-way associative cache without indirection.
	// TODO PERFORMANCE: Just use a U2 array directly, allowing for simpler lookups and more density, or smaller overall footprint (to keep everything in L1).
	buckets: @(PAGE) HashBucket[1<<13] (NOINIT); // rely on .bss being 0-initialised.
	// Overflow from buckets gets accumulated into more centralised, unordered sets. Ideally, none of these ever get used, but we still keep a few of them to limit the worst-case cost of vector reallocation and linear searches. We use unordered because we assume they will usually be small. You would probably need a gigantic codebase to trigger the pathological case, but then you should rather tweak the buckets instead or improve the hash function.
	overflow: std::[OverflowItem]Vec[128] (NOINIT);

	name_alloc: std::temp::Alloc := :custom(65536, 65536);
	strings: CHAR#[#]-std::Vec;
	GlobalDeclCount: U4 := 1;
	GlobalDeclsLut: U2[1<<16] (NOINIT);

	get(id: Identifier) CHAR#[#] -- := id.V < ##strings ?? strings[:ok(id.V)] : "<INVALID IDENT>"[#];

	get_global_decl(id: Identifier) GlobalDeclIdentifier -- := GlobalDeclsLut[id.V];


	GlobalToFileDeclAlloc: std::temp::Alloc := :custom(MI, MI);
	LocalToFileDeclAlloc:  std::temp::Alloc := :custom(MI, MI);

	GlobalToFileDeclLUTs: FileDeclIdentifier[#][2048] (NOINIT);
	LocalToFileDeclLUTs: FileDeclIdentifier[][2048] (NOINIT);

	get_file_decl_from_local(file: src::File, id: FileLocalIdentifier) FileDeclIdentifier --
		:= LocalToFileDeclLUTs[file][id.V];
	get_file_decl_from_global(file: src::File, id: Identifier) FileDeclIdentifier --
	{
		slice ::= GlobalToFileDeclLUTs[file];
		slice_raw ::= slice[];

		oor ::= (id.V >= ##slice);
		idx: U2 := oor ?? 0 : id.V;
		= slice_raw[idx];
	}
}

::rlc::ident init() VOID
{
	strings.reserve(65536);
	strings += "<NIL ID>"[#]; // [0] is an invalid ID.

	// touch all bucket pages to at least get the page faults out of the way.
	bucket_ptr: U1 \ := <U1 \>(<VOID \>(&buckets));
	FOR(offset ::= 0; offset < SIZEOF(#buckets); offset += PAGE)
		bucket_ptr[offset] := 0;
}

// Half-cacheline aligned because we do not want large loops in a bucket. This way, we get one more bit of hash selector, and get 5 entries per bucket, and 2 buckets per cacheline.
::rlc::ident HashBucket
{
	//Fingerprints: @(8) U4[1];
	Items:                     U2[1];

	# full() BOOL -- := Items[##Items -1] != 0;
}

::rlc::ident OverflowItem { Fingerprint: U4; Item: U2; } // For overflow.


::rlc::ident collisions: U4 := 0;
::rlc::ident collisions2: U4 := 0;
// Keep parallelism at number of parallel cache misses per core, or less. Prior outstanding cache misses might cause friction otherwise.
// Look up and/or insert.
::rlc::ident [#kN] multi_dedup(
	hashes: U8 #[],
	preimages: CHAR#[#] #[],
	ids: U2 []) VOID
{
	buckets: HashBucket * [kN] (NOINIT);

	// Calculate and prefetch all bucket addresses.
	|||{buckets} IT := &ident::buckets[hashes[IOTA] % ##ident::buckets];
	FOR(buckets) PREFETCH_READ IT;

	not_found ::= 1<<kN -1;

	// Prefetch all potentially matching elements in all buckets.
	FOR(buckets)
	{
		bucket ::= IT;
		hash ::= <U4>(hashes[IOTA] / ##ident::buckets);
		preimage ::= preimages[IOTA];

		//FOR(IT->Fingerprints)
			//IF(IT == hash)
		FOR(IT->Items)
				PREFETCH_READ mempool::get_memory(bucket->Items[IOTA]);
	}

	// Try to find the elements within the buckets, or insert if not found.
	FOR[find](buckets)
	{
		bucket ::= IT;
		workload ::= IOTA;
		hash ::= <U4>(hashes[IOTA] / ##ident::buckets);
		preimage ::= preimages[IOTA];

		FOR(IT->Items)
		//FOR(IT->Fingerprints)
			//IF(IT == hash)
			IF(IT)
			{
				item ::= bucket->Items[IOTA];
				str ::= ident::strings[item];

				IF(std::str::eq(preimage, str))
				{
					ids[workload] := item;
					not_found ^= 1 << workload;
					CONTINUE [find];
				}
			}

		// If bucket not full, and we did not find the element, insert it.
		IF(!IT->full())
			FOR(IT->Items)
				IF(IT == 0)
				{
					id ::= ##ident::strings;
						copy ::= <CHAR *>(name_alloc.alloc_raw_unaligned(##preimage));
						std::mem::cpy(copy[], preimage[], ##preimage);
						ident::strings += copy[FOR ##preimage];

					IF(id > 0xffff)
						term::error(NULL, "Too many distinct identifiers (max: 65535)");

					not_found ^= 1 << workload;
					ids[workload] := id;
					bucket->Items[IOTA] := id;
					//bucket->Fingerprints[IOTA] := hash;

					BREAK;
				}
	}

	// If any elements have neither been found nor could be inserted in the buckets, look in the overflow buckets.
	WHILE[overflow](not_found)
	{
		workload ::= FIRST1POS not_found;
		not_found ^= 1 << workload;
		hash ::= <U4>(hashes[workload] / ##ident::overflow);
		preimage ::= preimages[workload];
		// TODO IMPROVE PERFORMANCE: prefetch the buckets? We don't really care because this should rarely happen.
		extended_bucket ::= &ident::overflow[hashes[workload] % ##ident::overflow];

		FOR((*extended_bucket)!) {
			IF(IT.Fingerprint == hash)
			{
				mem ::= ident::strings[IT.Item];

				IF(std::str::eq(preimage, mem))
				{
					ids[workload] := IT.Item;
					CONTINUE [overflow];
				}
			}
		}

		// insert into the overflow bucket.
		id ::= ##ident::strings;
			copy ::= <CHAR *>(name_alloc.alloc_raw_unaligned(##preimage));
			std::mem::cpy(copy[], preimage[], ##preimage);
			ident::strings += copy[FOR ##preimage];

		collisions ++;

		IF(id > 0xffff)
			term::error(NULL, "Too many distinct identifiers (max: 65535)");

		ids[workload] := id;
		*extended_bucket += (hash, id);
	}
}

// Only look up.
::rlc::ident [#kN] multi_lookup(
	hashes: U8 #[],
	preimages: CHAR[#] #[],
	ids: U4 []) VOID
{
	buckets: HashBucket * [kN] (NOINIT);

	// Calculate and prefetch all bucket addresses.
	|||{buckets} IT := &ident::buckets[hashes[IOTA] % ##ident::buckets];
	FOR(buckets) PREFETCH_READ IT;

	not_found: U8 := 1<<kN -1;

	// Prefetch all potentially matching elements in all buckets.
	// TODO: we may want to make sure that we do not prefetch more entries than we have line fill buffers. But statistically, it should be extremely rare to get multiple matching hashes in one bucket.
	FOR(buckets)
	{
		bucket ::= IT;
		hash ::= <U4>(hashes[IOTA] / ##ident::buckets);
		preimage ::= preimages[IOTA];

		FOR(IT->Fingerprints)
			IF(IT == hash)
				PREFETCH_READ get_memory(bucket->Items[IOTA]);
	}

	// Try to find the elements within the buckets.
	FOR[find](buckets)
	{
		bucket ::= IT;
		workload ::= IOTA;
		hash ::= <U4>(hashes[IOTA] / ##ident::buckets);
		preimage ::= preimages[IOTA];

		FOR(IT->Fingerprints)
			IF(IT == hash)
			{
				item ::= bucket->Items[IOTA];
				mem ::= ident::strings[item];

				IF(std::str::eq(preimage, mem))
				{
					ids[workload] := item;
					not_found ^= 1 << workload;
					CONTINUE [find];
				}
			}
	}

	// If any elements have neither been found nor could be inserted in the buckets, look in the overflow buckets.
	WHILE[overflow](not_found)
	{
		workload ::= FIRST1POS not_found;
		not_found ^= 1 << workload;
		hash ::= <U4>(hashes[workload] / ##ident::overflow);
		preimage ::= preimages[workload];
		// TODO IMPROVE PERFORMANCE: prefetch the buckets? We don't really care because this should rarely happen.
		extended_bucket ::= &ident::overflow[hashes[workload] % ##ident::overflow];

		FOR((*extended_bucket)!) {
			IF(IT.Fingerprint == hash)
			{
				mem ::= ident::strings[IT.Item];

				IF(std::str::eq(preimage, mem))
				{
					ids[workload] := IT.Item;

					CONTINUE [overflow];
				}
			}
		}
	}
}