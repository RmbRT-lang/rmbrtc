
INCLUDE 'std/memory'
INCLUDE "mempool.rl"
INCLUDE 'std/vector'

::rlc::ident
{
	// Big global hashmap with 4Ki buckets (12 bit selector), and 10-way associative cache without indirection.
	buckets: @(PAGE) HashBucket[4<<10];
	// Overflow from buckets gets accumulated into more centralised, unordered sets. Ideally, none of these ever get used, but we still keep a few of them to limit the worst-case cost of vector reallocation and linear searches. We use unordered because we assume they will usually be small. You would probably need a gigantic codebase to trigger the pathological case, but then you should rather tweak the buckets instead or improve the hash function.
	overflow: std::[OverflowItem]Vec[128];

	alloc: std::temp::Alloc := :custom(65536, 65536);
	strings: CHAR#[#]-std::Vec;

	get(id: Identifier) CHAR#[#] -- := id < ##strings ?? strings[:ok(id)] : "<INVALID IDENT>"[#];
}

::rlc::ident init() VOID
{
	strings.reserve(65536);
	strings += "<NIL ID>"[#]; // [0] is an invalid ID.
}

::rlc::ident HashBucket
{
	Fingerprints: @(CACHELINE) U4[CACHELINE/6];
	Items:                     U2[CACHELINE/6];

	# full() BOOL -- := Items[##Items -1] != 0;
}

::rlc::ident OverflowItem { Fingerprint: U4; Item: U2; } // For overflow.

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

		FOR(IT->Fingerprints)
			IF(IT == hash)
				PREFETCH_READ mempool::get_memory(bucket->Items[IOTA]);
	}

	// Try to find the elements within the buckets, or insert if not found.
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
						copy ::= <CHAR *>(alloc.alloc_raw_unaligned(##preimage));
						std::mem::cpy(copy[], preimage[], ##preimage);
						ident::strings += copy[FOR ##preimage];

					IF(id > 0xffff)
						term::error(NULL, "Too many distinct identifiers (max: 65535)");

					not_found ^= 1 << workload;
					ids[workload] := id;
					bucket->Items[IOTA] := id;
					bucket->Fingerprints[IOTA] := hash;

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
			copy ::= <CHAR *>(alloc.alloc_raw_unaligned(##preimage));
			std::mem::cpy(copy[], preimage[], ##preimage);
			ident::strings += copy[FOR ##preimage];

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