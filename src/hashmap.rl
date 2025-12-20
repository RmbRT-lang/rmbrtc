
INCLUDE 'std/memory'
INCLUDE "mempool.rl"
INCLUDE 'std/vector'
::rlc::hashmap
{
	// Big global hashmap with 1Mi buckets (20 bit selector), and 8-way associative cache without indirection.
	buckets: @(PAGE) HashBucket[1<<20];
	// Overflow from buckets gets accumulated into more centralised, unordered sets. Ideally, none of these ever get used, but we still keep a few of them to limit the worst-case cost of vector reallocation and linear searches. We use unordered because we assume they will usually be small. You would probably need a gigantic codebase to trigger the pathological case, but then you should rather tweak the buckets instead or improve the hash function.
	overflow: std::[OverflowItem]Vec[1024];
}

::rlc::hashmap HashBucket
{
	Fingerprints: @(CACHELINE) U4[CACHELINE/8];
	Items:                     U4[CACHELINE/8];

	# full() BOOL -- := Items[##Items -1] != 0;
}

::rlc::hashmap OverflowItem { Fingerprint: U4; Item: U4; } // For overflow.

// TODO: support for item inlining.


// Keep parallelism at number of parallel cache misses per core, or less. Prior outstanding cache misses might cause friction otherwise.
// Look up and/or insert.
::rlc::hashmap [#kN] multi_dedup(
	hashes: U8[kN] #&,
	preimages: U1[#][kN]#&,
	ids: U4[kN] &) VOID
{
	buckets: HashBucket * [kN] (NOINIT);

	// Calculate and prefetch all bucket addresses.
	|||{buckets} IT := &hashmap::buckets[hashes[IOTA] % ##hashmap::buckets];
	FOR(buckets) PREFETCH_READ IT;

	candidates: U2 *[CACHELINE/8][kN];

	not_found ::= 1<<kN -1;

	// Prefetch all potentially matching elements in all buckets.
	// TODO: we may want to make sure that we do not prefetch more entries than we have line fill buffers.
	FOR(buckets)
	{
		bucket ::= IT;
		hash ::= <U4>(hashes[IOTA] / ##hashmap::buckets);
		preimage ::= preimages[IOTA];

		FOR(IT->Fingerprints)
			IF(IT == hash)
				PREFETCH_READ get_memory(bucket->Items[IOTA]);
	}

	// Try to find the elements within the buckets, or insert if not found.
	FOR[find](buckets)
	{
		bucket ::= IT;
		workload ::= IOTA;
		hash ::= <U4>(hashes[IOTA] / ##hashmap::buckets);
		preimage ::= preimages[IOTA];

		FOR(IT->Fingerprints)
			IF(IT == hash)
			{
				item ::= bucket->Items[IOTA];
				mem ::= <U2 *>(get_memory(item));
				len ::= *mem;
				obj ::= <U1 *>(&mem[1])[FOR len];

				IF(std::mem::eq(preimage, obj))
				{
					ids[workload] := item;
					not_found ^= 1 << workload;
					CONTINUE [find];
				}
			}

		// If bucket not full, and we did not find the element, insert it.
		IF(!IT->full() && not_found & 1 << workload)
			FOR(IT->Items)
				IF(IT == 0)
				{
					id ::=  mempool::insert_for_hashtable(preimage);

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
		hash ::= <U4>(hashes[workload] / ##hashmap::overflow);
		preimage ::= preimages[workload];
		// TODO IMPROVE PERFORMANCE: prefetch the buckets? We don't really care because this should rarely happen.
		extended_bucket ::= &hashmap::overflow[hashes[workload] % ##hashmap::overflow];

		FOR(*extended_bucket) {
			IF(IT.Fingerprint == hash)
			{
				mem ::= <U2 *>(get_memory(IT.Item));
				len ::= mem[-1];
				obj ::= <U1 *>(mem)[FOR len];

				IF(std::mem::eq(preimage, obj))
				{
					ids[workload] := IT.Item;

					CONTINUE [overflow];
				}
			}
		}

		// insert into the overflow bucket.
		id ::= mempool::insert_for_hashtable(preimage);
		ids[workload] := id;
		*extended_bucket += (hash, id);
	}
}

// Only look up.
::rlc::hashmap [#kN] multi_lookup(
	hashes: U8[kN] #&,
	preimages: U1[#][kN]#&,
	ids: U4[kN] &) VOID
{
	buckets: HashBucket * [kN] (NOINIT);

	// Calculate and prefetch all bucket addresses.
	|||{buckets} IT := &hashmap::buckets[hashes[IOTA] % ##hashmap::buckets];
	FOR(buckets) PREFETCH_READ IT;

	candidates: U2 *[CACHELINE/8][kN];

	not_found: U8 := 1<<kN -1;

	// Prefetch all potentially matching elements in all buckets.
	// TODO: we may want to make sure that we do not prefetch more entries than we have line fill buffers. But statistically, it should be extremely rare to get multiple matching hashes in one bucket.
	FOR(buckets)
	{
		bucket ::= IT;
		hash ::= <U4>(hashes[IOTA] / ##hashmap::buckets);
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
		hash ::= <U4>(hashes[IOTA] / ##hashmap::buckets);
		preimage ::= preimages[IOTA];

		FOR(IT->Fingerprints)
			IF(IT == hash)
			{
				item ::= bucket->Items[IOTA];
				mem ::= <U2 *>(get_memory(item));
				len ::= *mem;
				obj ::= <U1 *>(&mem[1])[FOR len];

				IF(std::mem::eq(preimage, obj))
				{
					ids[workload] := item;
					not_found ^= 1 << workload;
					CONTINUE [find];
				}
			}

		// If bucket not full, and we did not find the element, insert it.
		IF(!IT->full() && not_found & 1 << workload)
		not_found ^= <U8>(!IT->full()) << workload;
	}

	// If any elements have neither been found nor could be inserted in the buckets, look in the overflow buckets.
	WHILE[overflow](not_found)
	{
		workload ::= FIRST1POS not_found;
		not_found ^= 1 << workload;
		hash ::= <U4>(hashes[workload] / ##hashmap::overflow);
		preimage ::= preimages[workload];
		// TODO IMPROVE PERFORMANCE: prefetch the buckets? We don't really care because this should rarely happen.
		extended_bucket ::= &hashmap::overflow[hashes[workload] % ##hashmap::overflow];

		FOR(*extended_bucket) {
			IF(IT.Fingerprint == hash)
			{
				mem ::= <U2 *>(get_memory(IT.Item));
				len ::= mem[-1];
				obj ::= <U1 *>(mem)[FOR len];

				IF(std::mem::eq(preimage, obj))
				{
					ids[workload] := IT.Item;

					CONTINUE [overflow];
				}
			}
		}
	}
}