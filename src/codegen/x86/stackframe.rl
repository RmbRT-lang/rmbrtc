/// Bloom for looking through the stackframe to track allocations.
/// Allocates at U8 granularity in constant time, leading to smaller code and faster allocation.
::rlc::codegen::x86 U8StackFrame {
	HighestUsed: U4;
	PeakUsed: U4;
	WordsFreeBloom: U8;
	WordsFree: U8[64+ (/Dummy/) 1]; // Indexed by Bloom
	Scopes: U4[0xffff];

	// Constant-time, branch-less allocating of stack space.
	alloc_8() U4 --
	{
		size ::= HighestUsed;
		// Generate 
		firstFreeWord_bloombit ::= FIRST1BIT WordsFreeBloom;
		WordsFreeBloom ^= firstFreeWord_bloombit;
		firstFreeWord_bloomidx ::= POPCNT (firstFreeWord_bloombit-1); // SISD...
		firstFreeWord_slot_bits ::= WordsFree[firstFreeWord_bloomidx];
		firstFreeWord_slot_bit ::= FIRST1BIT firstFreeWord_slot_bits;
		firstFreeWord_slot_bits ^= firstFreeWord_slot_bit;
		WordsFree[firstFreeWord_bloomidx] := firstFreeWord_slot_bits;
		firstFreeWord_idx ::= POPCNT (firstFreeWord_slot_bit - 1);
		index ::= (firstFreeWord_bloomidx << 6) | firstFreeWord_idx;
		index := firstFreeWord_bit ?? size : index;

		// Now, we do generic tracking.
		size += index == size;
		HighestUsed := size;
		Peak := (Peak < size) ?? size: Peak;
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