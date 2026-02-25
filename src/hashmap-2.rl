
INCLUDE 'std/memory'
INCLUDE "mempool.rl"
INCLUDE 'std/vector'

// NOTE: We can later on use VPGATHERDD, maybe, for massive amounts of lookups, although page faults and cache misses might make this unusable. But the current design lends itself well towards vectorisation.
::rlc::hashmap
{
	// Big global hashmap with 1Mi buckets (20 bit selector), and 8-way associative cache without indirection.
	buckets: @(PAGE) HashBucket[1<<21];
	// Overflow from buckets gets accumulated into more centralised, unordered sets. Ideally, none of these ever get used, but we still keep a few of them to limit the worst-case cost of vector reallocation and linear searches. We use unordered because we assume they will usually be small. You would probably need a gigantic codebase to trigger the pathological case, but then you should rather tweak the buckets instead or improve the hash function.
	overflow: std::[OverflowItem]Vec[1024];
}

::rlc::hashmap HashBucket
{
	Fingerprints: @(CACHELINE/2) U4[(CACHELINE/2)/8];
	Items:                     U4[(CACHELINE/2)/8];

	# full() BOOL -- := Items[##Items -1] != 0;
}

::rlc::hashmap OverflowItem { Fingerprint: U4; Item: U4; } // For overflow.

// TODO: support for item inlining.
	// TODO: ^ check whether already implemented or what was meant.
		// ^: Probably meant that we can directly store the item in the hash table if it is short enough.

// Keep parallelism at number of parallel cache misses per core, or less. Prior outstanding cache misses might cause friction otherwise.
// Look up and/or insert.
// IMPORTANT: preimages must be distinct, or duplicate insertions can happen.
::rlc::hashmap [#kN] multi_dedup(
	hashes: U8[] #&,
	preimages: U1#[#][]#&,
	ids: U4[] &) VOID
{
	buckets: HashBucket * [kN] (NOINIT);

	// Calculate and prefetch all bucket addresses.
	|||{buckets} IT := &hashmap::buckets[hashes[IOTA] % ##hashmap::buckets];
	FOR(buckets) PREFETCH_READ IT;

	not_found ::= 1<<kN -1;

	// Prefetch all potentially matching elements in all buckets.
	// TODO: we may want to make sure that we do not prefetch more entries than we have line fill buffers.
	(/FOR(buckets)
	{
		bucket ::= IT;
		hash ::= <U4>(hashes[IOTA] / ##hashmap::buckets);
		preimage ::= preimages[IOTA];

		FOR(IT->Fingerprints)
			IF(IT == hash)
				PREFETCH_READ get_memory(bucket->Items[IOTA]);
	}/)

	hash_matches: U2[kN] := 0;
	entries_free: U2[kN] := 0;
	any_matches: U4 := 0; // whether there were any matches per bucket.
	any_free: U4 := 0;

	// Find all matching elements per bucket, and whether a bucket has matches.
	FOR[find_pre](buckets)
	{
		hash ::= <U4>(hashes[IOTA] / ##hashmap::buckets);
		workload ::= IOTA;
		bucket ::= IT;

		// Matching hashes in the bucket.
		hm_local: U2 := 0;
		ef_local: U2 := 0;
		am_local: U4 := 0;
		af_local: U4 := 0;
		FOR(IT->Fingerprints) // this should be unrolled, ideally, so it becomes branchless.
		{
			match ::= IT == hash;
			empty ::= bucket->Items[IOTA] == 0;
			PREFETCH_READ get_memory(match ?? bucket->Items[IOTA]:0);
			am_local |= <U4>(match) << workload;
			af_local |= <U4>(empty) << workload;
			hm_local |= <U2>(match) << IOTA;
			ef_local |= <U2>(empty) << IOTA;
		}
		hash_matches[IOTA] := hm_local;
		entries_free[IOTA] := ef_local;
		any_matches |= am_local;
		any_free |= af_local;
	}

	// Only look at buckets that had matches.
	WHILE[find_post](any_matches)
	{
		workload ::= FIRST1POS any_matches;
		any_matches ^= 1<<workload;
		bucket ::= buckets[workload];
		preimage ::= preimages[workload];
		hash ::= <U4>(hashes[workload] / ##hashmap::buckets);
		hm_local ::= hash_matches[workload];

		// Go through all matches in the bucket.
		DO(idx ::= FIRST1POS hm_local)
		{
			hm_local ^= 1<<idx;
			item ::= bucket->Items[idx];
			idx := FIRST1POS hm_local;

			mem ::= <U2 *>(get_memory(item));
			len ::= *mem;

			preimage_8 ::= <U8 *>(&preimage[0])[FOR len >> 3];
			obj_8 ::= <U8 *>(&mem[1])[FOR len>>3];
			preimage_rest ::= preimage[FROM len &~ 7];
			obj_rest ::= <U1 *>(&mem[1])[FROM len &~ 7 UNTIL len];

			IF(std::mem::eq(preimage_8, obj_8)
			&& std::mem::eq(preimage_rest, obj_rest))
			{
				ids[workload] := item;
				not_found ^= 1 << workload;
				CONTINUE [find_post];
			}
		} WHILE(hm_local)
	}

	// If bucket not full, and we did not find the element, insert it.
	free_not_found ::= not_found & any_free;
	WHILE[not_found_free](free_not_found)
	{
		workload ::= FIRST1POS free_not_found;
		free_not_found ^= 1 << workload;
		hash ::= <U4>(hashes[workload] / ##hashmap::overflow);
		preimage ::= preimages[workload];
		bucket ::= buckets[workload];

		idx ::= FIRST1POS entries_free[workload];
		id ::= mempool::insert_for_hashtable(preimage);

		ids[workload] := id;
		bucket->Items[idx] := id;
		bucket->Fingerprints[idx] := hash;
	}

	// If any elements have neither been found nor could be inserted in the buckets, look in the overflow buckets.
	not_found &= ~any_free;
	WHILE[overflow](not_found)
	{
		workload ::= FIRST1POS not_found;
		not_found ^= 1 << workload;
		hash ::= <U4>(hashes[workload] / ##hashmap::overflow);
		preimage ::= preimages[workload];
		bucket ::= buckets[workload];

		// TODO IMPROVE PERFORMANCE: prefetch the buckets? We don't really care because this should rarely happen.
		extended_bucket ::= &hashmap::overflow[hashes[workload] % ##hashmap::overflow];

		FOR((*extended_bucket)!) {
			IF(IT.Fingerprint == hash)
			{
				mem ::= <U2 *>(mempool::get_memory(IT.Item));
				len ::= mem[-1];
				obj ::= <U1 #*>(mem)[FOR len];

				IF(len == ##preimage && std::mem::eq(preimage[], obj[], len))
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

				preimage_8 ::= <U8 *>(&preimage[0])[FOR len >> 3];
				obj_8 ::= <U8 *>(&mem[1])[FOR len>>3];
				preimage_rest ::= preimage[FROM len &~ 7];
				obj_rest ::= <U1 *>(&mem[1])[FROM len &~ 7 UNTIL len];

				// We could have a variant that does not need to check for equality when looking up, if we know that it must exist already, and if we reserve one bit in the hash to indicate hash uniqueness. However, I am not sure whether such a situation exists, because if we know it exists, and we have its hash, then we should also already know its location.
				IF(std::mem::eq(preimage_8, obj_8)
				&& std::mem::eq(preimage_rest, obj_rest))
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