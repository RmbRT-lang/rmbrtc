
INCLUDE 'std/heap'
::rlc::mempool
{
	// append-only memory pool, connected to a hashtable. However, it might be possible to drop entire phases.

	// dimensions must be equal and a power of two.
	// We allocate 64MiB chunks of memory.
	// We align the array to cacheline size to contain small allocations inside single cachelines for faster access.
	chunk0: @(CACHELINE) U2[32<<20] (NOINIT);
	chunksN: @(CACHELINE) U2[32<<20] *[16*8] (NULL); // Up to 8 GiB, in 64 MiB chunks.

	progress: U4 := 1;
	progressMem: U2 * := &chunk0[1];

	init() VOID { chunksN[0] := &chunk0; }

	get_memory(addr: U4) VOID * --
	{
		IF(!addr) = NULL;

		/// Ideally, we would have a fixed address that we use, which would reduce the memory latency. But then again, it doesn't really matter much, because we need to bridge a cache miss anyway. But if we could have one large buffer that automatically grows on page faults, that would be great.
		(/IF(addr < ##chunk0)
			= &chunk0[addr];
		ELSE/)
			= &(*chunksN[addr / ##chunk0])[addr % ##chunk0];
	}

	// queries multiple memory locations from the mempool and prefetches them.
	[#kN] get_memory_simd(
		addrs: @(SIMD) U4[kN] #&,
		mem: @(SIMD) VOID *[kN] &) VOID --
	{
		|||{kN}
		{
			chunk: U4 := addrs[IOTA] / ##chunk0;
			offset: U4 := addrs % ##chunk0;
			ptr ::= chunksN[chunk];
			mem[IOTA] := &(*ptr)[offset];
			PREFETCH_READ mem;
		}
	}

	alloc_unhashed(size: U4) {VOID *, MemID} {
		words ::= (size + 1) >> 1;
		progress ::= mempool::progress;
		progressMem ::= mempool::progressMem;

		// Try to contain allocations to a cacheline.
		//  (CACHELINE/2 because of SIZEOF(U2)).
		alignProgress ::= progress + (CACHELINE/2-1) &~ (CACHELINE/2-1);
		alignProgressMem ::= <U2 *>(<UM>(progressMem) + (CACHELINE-1) &~ (CACHELINE-1));
		crossesCacheline ::= progress + words & CACHELINE/2 != progress & CACHELINE/2;
		//  (CACHELINE-2 because of SIZEOF(U2) length tag).
		realign ::= (size < CACHELINE-2) && crossesCacheline;

		alignProgress := realign ?? alignProgress : progress;
		alignProgressMem := realign ?? alignProgressMem : progressMem;
		end ::= alignProgress + words;

		// Does not cross chunk boundaries?
		IF(end / ##chunk0 == progress / ##chunk0)
		{
			mem ::= mempool::progressMem;
			id ::= mempool::progress;

			mempool::progress := alignProgress + words;
			mempool::progressMem := alignProgressMem + words;

			= (mem, id);
		} ELSE
		{
			// If it crosses a chunk boundary, alloc a new chunk.
			ASSERT(size < SIZEOF(#chunk0));

			chunk ::= (alignProgress + words) / ##chunk0;
			chunksN[chunk] := >std::heap::alloc.alloc_raw_region(
				SIZEOF(#mempool::chunk0),
				CACHELINE);

			mem : U2 * := &(*chunksN[chunk])[0];
			id ::= chunk * ##chunk0;

			mempool::progress := chunk * ##chunk0 + words;
			mempool::progressMem := mem + words;

			= (mem, id);
		}
	}

	[T]alloc_unhashed_t() {T *, T-Handle} -- {
		x ::= alloc_unhashed(SIZEOF(T));
		= (<T *>(x.(0)), x.(1));
	}

	[T]alloc_unhashed_array(count: U4) {T[#], MemID} -- {
		x ::= alloc_unhashed(SIZEOF(T) * count);
		= (<T *>(x.(0))[FOR count], x.(1));
	}

	// memory layout: {size: U2; payload: U1[?]}, id points at payload.
	alloc_for_hashtable(size: U4) {VOID *, MemID}
	{
		ASSERT(size <= 0xffff);
		words ::= (size + 3) >> 1; // one extra word for the size tag.
		progress ::= mempool::progress;
		progressMem ::= mempool::progressMem;

		// Try to contain allocations to a cacheline.
		//  (CACHELINE/2 because of SIZEOF(U2)).
		alignProgress ::= progress + (CACHELINE/2-1) &~ (CACHELINE/2-1);
		alignProgressMem ::= <U2*>(<UM>(progressMem) + (CACHELINE-1) &~ (CACHELINE-1));
		crossesCacheline ::= progress + words & CACHELINE/2 != progress & CACHELINE/2;
		//  (CACHELINE-2 because of SIZEOF(U2) length tag).
		realign ::= (size < CACHELINE-2) && crossesCacheline;

		alignProgress := realign ?? alignProgress : progress;
		alignProgressMem := realign ?? alignProgressMem : progressMem;
		end ::= alignProgress + words;

		// Does not cross chunk boundaries?
		IF(end / ##chunk0 == progress / ##chunk0)
		{
			*alignProgressMem := size;
			mem ::= mempool::progressMem + 1;
			id ::= mempool::progress + 1;
			mempool::progress := alignProgress + words -1;
			mempool::progressMem := alignProgressMem + words - 1;

			= (mem, id);
		} ELSE
		{
			// If it crosses a chunk boundary, alloc a new chunk.
			ASSERT(size < SIZEOF(#mempool::chunk0));

			chunk ::= (alignProgress + words) / ##chunk0;
			// TODO: use a guaranteed 0-initialising allocator here.
			mempool::chunksN[chunk] := >std::heap::alloc.alloc_raw_region(
				SIZEOF(#mempool::chunk0),
				CACHELINE);

			mem : U2 * := &(*chunksN[chunk])[0];
			*mem := size;
			mem := mem+1;
			id ::= chunk * ##chunk0 + 1;

			mempool::progress := chunk * ##chunk0 + words -1;
			mempool::progressMem := mem + words -1;

			= (mem, id);
		}
	}

	[T]
	insert_unhashed_array(obj: T![#]) {T[#], MemID} {
		size ::= ##obj * SIZEOF(T);
		alloc ::= mempool::alloc_unhashed(size);
		dst ::= <T *>(alloc.(0))[FOR ##obj];
		FOR(dst) IT.{ &&obj[IOTA] };
		= (dst, alloc.(1));
	}

	insert_unhashed(obj: U1#[#]) MemID {
		alloc ::= mempool::alloc_unhashed(##obj);
		std::mem::cpy(alloc.(0), obj[], ##obj);
		= alloc.(1);
	}

	insert_for_hashtable(obj: U1#[#]) MemID {
		alloc ::= mempool::alloc_for_hashtable(##obj);
		std::mem::cpy(alloc.(0), obj[], ##obj);
		= alloc.(1);
	}
}

::rlc TYPE MemID := U4;
::rlc [T] Handle {
	mem: MemID;
	# *THIS T& -- := *<T *>(mempool::get_memory(mem));
	# <BOOL> -- := mem != 0;
	# get() T * -- := <T *>(mempool::get_memory(mem));
}