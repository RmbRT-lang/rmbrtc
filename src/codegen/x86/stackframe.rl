/// Bloom for looking through the stackframe to track allocations.
/// Allocates at U8 granularity in constant time, leading to smaller code and faster allocation.
::rlc::codegen::x86 U8StackFrame {
	HighestUsed: U4; // current tip.
	PeakUsed: U4;    // max capacity.
	WordsFreeBloom: U8;
	WordsFree: U8[64+ (/Dummy/) 1]; // Indexed by Bloom
	Scopes: U4[0xffff];

	// Constant-time, branch-less allocating of stack space.
	alloc_8() U4 --
	{
		size ::= HighestUsed;
		// Generate  (… ???)
		firstFreeWord_bloombit ::= FIRST1BIT WordsFreeBloom;
		WordsFreeBloom ^= firstFreeWord_bloombit; // FIRST1POS/LZCNT + BTR
		firstFreeWord_bloomidx ::= POPCNT (firstFreeWord_bloombit-1); // can be removed if ^.
		
		// NOTE: Can also use FIRST1POS + BTR here. FIRST1POS would be 3-4 Intel, 1-2 AMD cycles.
		firstFreeWord_slot_bits ::= WordsFree[firstFreeWord_bloomidx];
		firstFreeWord_slot_bit ::= FIRST1BIT firstFreeWord_slot_bits;
		firstFreeWord_slot_bits ^= firstFreeWord_slot_bit;
		WordsFree[firstFreeWord_bloomidx] := firstFreeWord_slot_bits;
		firstFreeWord_idx ::= POPCNT (firstFreeWord_slot_bit - 1); // can be removed if FIRST1POS

		// We can probably do this better.
		index ::= (firstFreeWord_bloomidx << 6) | firstFreeWord_idx;
		index := firstFreeWord_bloombit ?? size : index;

		// Now, we do generic tracking.
		size += index == size;
		HighestUsed := size;
		PeakUsed := (PeakUsed < size) ?? size : PeakUsed;
		= index;
	}

	// Constant-time, branch-less freeing of stack space.
	free_8(index: U4) VOID --
	{
		size ::= Size;
		size := (index +1 == size) ?? index : size;
		Size := size;

		clearBit ::= <U8>(index < 64*64); // if 0, the rest turns into nop.
		// rotation saves us an &63, since it is already guaranteed index%64, which shifting isn't.
		WordsUsed[(index >> 6) & 63] &= ~(clearBit <<< index);
		BloomFull &= clearBit << (index >> 6);
	}
}

// Actually, this belongs in the stage-1 code generator. Stage-2 only consumes instructions to print.
::rlc::codegen::x86 [#N] BumpStackFrames {
	Used: @(SIMD) U4[N];
	PeakUsed: @(SIMD) U4[N];
	ScopeDepth: @(SIMD) U2[N];
	Scopes: U4[1024][N];
}