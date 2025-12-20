
INCLUDE 'std/heap'
::rlc::mempool
{
	// dimensions must be equal and a power of two.
	// We allocate 64MiB chunks of memory.
	// We align the array to cacheline size to contain small allocations inside single cachelines for faster access.
	chunk0: @(CACHELINE) U2[32<<20] (NOINIT);
	chunksN: @(CACHELINE) U2[32<<20] *[16*8] (NULL); // Up to 8 GiB, in 64 MiB chunks.

	progress: U4 := 0;
	progressMem: U2 * := &chunk0[0];


	init() VOID { chunksN[0] := &chunk0; }

	get_memory(addr: U4) VOID * --
	{
		/// Ideally, we would have a fixed address that we use, which would reduce the memory latency. But then again, it doesn't really matter much, because we need to bridge a cache miss anyway. But if we could have one large buffer that automatically grows on page faults, that would be great.
		(/IF(addr < ##chunk0)
			= &chunk0[addr];
		ELSE/)
			= &chunksN[addr / ##chunk0][addr % ##chunk0];
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
			mem[IOTA] := &ptr[offset];
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
		realign ::= (size < CACHELINE) && crossesCacheline;

		alignProgress := realign ?? alignProgress : progress;
		alignProgressMem := realign ?? alignProgressMem : progressMem;
		end ::= alignProgress + words;

		// Does not cross chunk boundaries?
		IF(end & ##chunk0 == progress & ##chunk0)
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

	// memory layout: {size: U2; payload: U1[]}, id points at payload.
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
		IF(end & ##chunk0 == progress & ##chunk0)
		{
			*alignProgressMem := size;
			mem ::= mempool::progressMem + 1;
			id ::= mempool::progress + 1;
			mempool::progress := alignProgress + words;
			mempool::progressMem := alignProgressMem + words;

			= (mem, id);
		} ELSE
		{
			// If it crosses a chunk boundary, alloc a new chunk.
			ASSERT(size < SIZEOF(#mempool::chunk0));

			chunk ::= (alignProgress + words) / ##chunk0;
			mempool::chunksN[chunk] := >std::heap::alloc.alloc_raw_region(
				SIZEOF(#mempool::chunk0),
				CACHELINE);

			mem : U2 * := &(*chunksN[chunk])[0];
			*mem := size;
			id ::= chunk * ##chunk0 + 1;
			mempool::progress := chunk * ##chunk0 + words;
			mempool::progressMem := mem + words;

			= (mem+1, id);
		}
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
::rlc [T] Handle { mem: MemID; # *THIS T& -- := *<T *>(mempool::get_memory(mem)); }
// 0 is invalid / none.
::rlc TYPE Identifier := U2;