INCLUDE 'std/vector'
INCLUDE 'std/tempalloc'


::rlc::codegen::x86::dumb
{
	// CODEGEN NOTES: we probably first want a forwards pass over the IR for typechecking, but a backwards pass over the IR for the initial register allocation, which lets us identify constraints regarding which operations require which values in what registers. And then we do a forward pass that inserts loads, spills, and migration operations to satisfy the constraints. We can then do another pass over the registers and values to identify pathological patterns. This could be done using a circuit.

	
	Swar4x12 { // We prefer SWAR over memory accesses, because SWAR is SIMD-isable. We want to operate on multiple instances at once.
		Storage: U8;

		:splat{clamped: U1}--: Storage := 0x0084210842108421 * clamped;

		// NOTE for RISA: these techniques are too slow on x86. The simple implementation using memory is actually faster, it seems. Mainly because x86 does not offer good SWAR techniques, especially the shift amounts and mask creation takes too long.
		(/ To make SWAR actually worthwhile, we need:
		- getEntry: i, entrySize: = x >> (entrySize * i) & ((1<<entrySize)-1)
			- Or even just bitmask n := (1 << n) -1 in one cycle. It's actually just like ~(-1 >> (N-n)), so it's not that special. Basically shift up, but fill with ones instead of 0s. so it would be: 0 "<<1" n.
				- We could actually revert the whole thing and use right shifts, but only if we can guarantee that there's always a sign bit.
			- We want fast index calculations for slots, for sizes 3 and 5 and maybe 9. Single-cycle.
			- We want to cut and insert into words, shifting stuff around:
				??? insert low, high
			- we want a native add, subtract:
				swar_add a, b, carry_mask
				-- where carry_mask limits the propagation of carries. This eliminates the need for wasted bits, and it can return the sum and additionally the carries in the mask. Not sure how that works with subtraction, as we would need the equivalent of a + (~b + 1), but where 1 is derived from the carry mask. This could also be used for ADC-style addition with carry: if the lowest bit in the mask accepts carry-in, we can feed it the carry or something.
				- Carry mask marks all the "1" bits (the start of each word). Then, negating is easy, because you can do swar_add ~x, 1_mask, 1_mask. Theoretically, swar_sub could either do two swar_adds, or merge that.
			- We also want bit blending: (a & mask) | (b &~ mask)
			- We also want nibble splat: x * 0x1111111111111111 (x&0xf)
			- We also want byte splat:   x * 0x0101010101010101 (<U1>(x))
			- We also want U2 splat:     x * 0x0001000100010001 (<U2>(x))
			- We also want U4 splat:     x * 0x0000000100000001 (<U4>(x))
			- We also want a nibble-shift: (x >> (n*4))
			- We also want a byte-shift:   (x >> (n*8)), single-cycle. Same for rotates.
			- We also want ... /)
		# get_unclamped(i: U1) U1 -- := Storage >> (5 * i);
		set_clamped(i: U1, v: U1) VOID -- { Storage |= <U8>(v) << (5 * i); }

		// Remove entry and shift all following entries downwards.
		// 4-5 cycles, expect 5. However, if Storage is not in a register, then we have 8 cycles or something. But since Storage is a fixed address, we can expect it to already be in a register. However, not requiring any memory accesses, this is great for interleaving, amortised latencies of 2-3 cycles might be possible.
		erase_entry(i: U1) VOID -- {
			// 2-3 cycles, expect 3.
			shl ::= 5*i; // 1-2 cycles, expect 2. Note, get_unclamped also uses this.
			maskNotLower ::= (~<U8>(0) << shl); // 1 cycle

			// 1 cycle.
			// Mask all entries before the erased entry.
			low ::= Storage &~ maskNotLower;
			// Mask all entries after the erased entry.
			high ::= (Storage >> 5) & maskNotLower;

			// 1 cycle.
			// Merge.
			Storage := low | high;

			(/ Cycles & registers:

			1	;                         MOV maskNotLower, ~0;        MOV low, Storage;
			2	LEA shl, [i+4*i];         SHR Storage, 5;              ;
			3	SHL maskNotLower, shl;    ;                            ;
			4	ANDN low, maskNotLower;   AND Storage, maskNotLower;   ;
			5	OR Storage, low           ;                            ;

				i/shl is the input. we only use Storage, i/shl, maskNotLower, and low. 4 registers. This means we can run at least two instances in one register set, + pipelining. The only permanent register is Storage, the others are short-lived. Maybe i also has to survive. Anyway, perfect fit for r8-r15, although the shift instructions need to temporarily use CL.
			/)
		}

		// Assumes all entries are clamped to 4-bit numbers, so msb is always 0.
		(/ cycles: 7

		1	;                                  x := storage + SPLAT5_15;
		2	;                                  ;
		3	splatted := clamped * SPLAT5_1;    ;
		4	t1 := x - splatted                 ;
		5	t1 := t1 & ~SPLAT5_15              ;
		6	gt := t1 >> 4                      ;
		7	Storage -= gt;                     ;

		We can also remove the final shift, probably:

		1	;                                    x := storage + SPLAT5_15;
		2	;                                    x >>= 4;
		3	splatted := clamped * (SPLAT5_1>>4)  ;
		4	t1 := x - splatted                   ;
		5	t1 := t1 &~ SPLAT5_15>>4             ;
		6	Storage -= gt;                       ;

		Though I am not sure whether that works as intended. Maybe we would need some tweaking to not lose the lowest bits.

		Either way, this is easy to run in parallel, and does not use many registers. We should be able to run both functions at once without any spills.

		NOTE: this only turns into a NOP if clamped == 15 or something.
		/)
		dec_if_gt(clamped: U1) VOID -- {
			// for each element, x + dist must be < 15 if x < clamped.
			splat15: U8 := 0x0084210842108421 * 15;
			splatted: U8 := clamped * 0x0084210842108421; // 3
			x ::= Storage + splat15; // 1
			gt ::= ((x - splatted) &~ splat15) >> 4; // 1+2
			Storage -= gt; // all digits where we subtract are nonzero, so no additional guards needed. // 1
		}



		// Should take around 11-12 cycles.
		// NOTE: to make this nop-friendly, we either have to manipulate the input values or use a conditional move at the end.
		clobber(reg: U1) VOID
		{
			lru: Swar4x12; // : for figuring out what register to spill.
			order: Swar4x12; // : for knowing where a specific register is.
			i ::= order.get_unclamped(reg) & 0xf; // 3+1
			order.dec_if_gt(i); lru.erase(i); lru.append(reg); // 7;   5+2
		}

		// Should take around 13-14 cycles.
		spill_lru() U1 // spill the least recently used register.
		{
			lur: Swar4x12;
			order: Swar4x12;

			reg ::= lru & 0xf; // 1
			lru >>= 4; // 1
			i ::= order.get_unclamped(reg) & 0xf; // 4
			order.dec_if_gt(i); // 7
			= reg;
		} // we should be able to combine clobber and spill, and combine it with a flag doing conditional assignments at the end, and with the flag also controlling whether to take a register name, or the least recently used register.

		// at 7M LOC/s and 20 ops/LOC, we have a budget of 7.14ns/op, or around 28 cycles. I assume we can bring most of the register logic into around 16 cycles, leaving us with another 12 cycles or so for managing the stack frame.
		touch(reg: U1) VOID
		{
			// essentially the same as clobber, except that in clobber, we care about whether we have to spill a value first.
		}
	}
	Swar4x16 {
		Storage: U8;
		// 4 cycles, assuming Storage is already in a register, and we have ANDN.
		// 5 cycles if no ANDN.
		erase_entry(i: U1) VOID -- { // LRU::erase_entry
			shl ::= i << 2;
			maskNotLower ::= ~<U8>(0) << shl;
			low ::= Storage &~ maskNotLower;
			high ::= (Storage >> 4) & maskNotLower;
			Storage := low | high;
		}

		// 3 cycles, assuming Storage is already in a register.
		get(i: U1) U1 -- := (Storage >> (i<<2)) & 15;

		// 7 cycles, assuming Storage is already in a register.
		dec_if_gt(v: U1) VOID -- { // IndexList::on_erased_entry
			splatted: U8 := v * 0x0101010101010101;
			mask: U8 := 0x0f0f0f0f0f0f0f0f;
			diff_even ::= (Storage & mask) + mask;
			diff_odd ::= ((Storage >> 4) & mask) + mask;
			diff_even -= splatted;
			diff_odd -= splatted;
			gt_even ::= diff_even & 0x1010101010101010;
			gt_odd  ::= diff_odd  & 0x1010101010101010;
			// gt flag is now at 0x1010101010101010.
			Storage -= gt_odd;
			Storage -= (gt_even >> 4);
		}
	}

	[N:NUMBER] Simd_LRU16s {
		// Positions: index of register in the queue, or -1, if not in queue. Indices > register count: -1.
		Positions: @(SIMD) S1[16][N];
		// Queue nibbles: if in queue, ~reg, otherwise, 0. Highest nibbles (exceeding queue max capacity) are reserved for 0.
		// Removing an element shifts down all following elements by one nibble (filling up with 0s).
		// inserting a new element at the top: OR. Shifts/writes are masked off if the insertion is a NOP.
		// Queue inserts at a fixed position.
		Queue: @(SIMD) U8[N];

		{}: Positions(-1), Queue(0x0000000000000000);

		// To turn this into a NOP, pass in reg == 16
		remove(reg: S1[N] #&) VOID
		{
			|||{reg}
			{
				i ::= IOTA;
				pos ::= Positions[i][IT & 15] | (IT & 16); // 16-31 if reg == 16
				|||{Positions[i]} IT -= (IT > pos); // NOP if reg == 16

				shl ::= pos << 1; // 0-30 if ok, 32-60 if reg == 16
				maskNotLower ::= (~<U8>(0) << shl) << shl; // 0 if reg == 16.
				low ::= Queue[i] &~ maskNotLower;
				high ::= (Queue[i] >> 4) & maskNotLower;
				// Insert register at highest point. NOP if reg == 16.
				Queue[i] := low | high;
			}
		}

		(/ SIMD(N): Branchlessly optionally evict an entry from the LRU queue, and optionally reinsert it at the top.
			reg: the register (TempRegName) to evict. Pass 15 to turn this whole function into a NOP.
			reinsert: bit array (up to SIMD 64): whether to re-insert the register. /)
		remove(reg: U1[N] #&, reinsert: U8#) VOID
		{
			// LUT[reg]: SIMD16: IOTA >= reg.
			// We use this mask to blend the shift of the queue eviction.
			// Passing in reg 15 will disable the shift entirely.
			// nibble 15 also never gets written and stays constant.
			// We also mask out any columns that are not part of the enum.
			STATIC newerMasks: U8#[16] (
				0x0fffffffffffffff & ((1 << 4*###TempRegName) -1),
				0x0ffffffffffffff0 & ((1 << 4*###TempRegName) -1),
				0x0fffffffffffff00 & ((1 << 4*###TempRegName) -1),
				0x0ffffffffffff000 & ((1 << 4*###TempRegName) -1),
				0x0fffffffffff0000 & ((1 << 4*###TempRegName) -1),
				0x0ffffffffff00000 & ((1 << 4*###TempRegName) -1),
				0x0fffffffff000000 & ((1 << 4*###TempRegName) -1),
				0x0ffffffff0000000 & ((1 << 4*###TempRegName) -1),
				0x0fffffff00000000 & ((1 << 4*###TempRegName) -1),
				0x0ffffff000000000 & ((1 << 4*###TempRegName) -1),
				0x0fffff0000000000 & ((1 << 4*###TempRegName) -1),
				0x0ffff00000000000 & ((1 << 4*###TempRegName) -1),
				0x0fff000000000000 & ((1 << 4*###TempRegName) -1),
				0x0ff0000000000000 & ((1 << 4*###TempRegName) -1),
				0x0f00000000000000 & ((1 << 4*###TempRegName) -1),
				0x0000000000000000 & ((1 << 4*###TempRegName) -1)
			);

			|||{reg}
			{ // should be like 4-5 cycles per iteration, amortised.
				(/ TODO: unify spilling into this, too.
					What cases are there?
					- do nothing at all. (reg = 15)
					- touch register r (evict + insert). (reg, reinsert = 1)
					- evict register r (evict). (reg, reinsert = 0)
					- allocate a new register, return evicted register.

					What we actually want to do with this:
					1. we want to load a temporary value.
					2. If it not in a register?
						1. is this the last use of the value?
							1. Yes:
								1. Use memory operand.
							2. No:
								1. allocate a register for it.
								2. Did we evict a register? if so, spill it.
								3. Use the register operand.
					3. Generate instruction based on chosen operand.
					4. Was this the last use of the value, and it was a register?
						1. Yes:
							1. evict it (reg, reinsert = 0)
						2. No:
							1. NOP (reg = 15)

					We need to have 2.1. and 4. as part of the IR's information, alongside the ID of the temporary value and its type.
					Additionally, we want to have a case for constants, just like with memory operands. We might need an additional bit of information here. Maybe we can tell the IR roughly how many values we can keep track of, so that it can decide for us when to mark a value as final or not. After all, we do not want to evict a register for a constant that only gets reused much later on, and is better used as an immediate anyway. Same with variables in general. An eviction hint, basically. Additionally, the IR can keep track of when to insert prefetches, because we do not want to optimise bytecode by parsing it and analysing it. The optimisations should all happen beforehand. But maybe a codegen-specific optimisation pass can run over bytecode in -O2 or something.

					Additionally, we have the case where an instruction can be a jump label or not. We also need to know whether we are in SIMD or not, although that should probably be an if in the main loop that iterates over the IR stream. The codegenerator needs some kind of state machine, but it should have basically no state transitions during most code.

					Wherever possible, we want to avoid branches, because they destroy SIMD. We want a branchless version, and if we need to incur latency hits, that is acceptable, as long as we can amortise them with throughput.

					We can also classify workloads maybe and use buckets that share the same branches. Although per-instruction sorting into buckets might be a bit too slow, since the workload is so small. Or, we have one big list of things, each classified by a bitmask, and iterate over the list and do either NOP or useful work, and just go over that list twice or something. But that is only worth it if it simplifies the branchless workloads by a lot.

					Plan: implement exactly this. Then, make the IR. We probably need 3-4 rewrites of everything.
				/)

				i ::= IOTA;
				pos ::= Positions[i][IT]; // -1/255 if reg == 15.
				// 1. decrement all newer than register's old position (NOP if 15/-1, due to signed compare).
				|||{Positions[i]} IT -= (IT > reg[i]); // this should literally take like one cycle per SIMD, the bottleneck being the loading of `pos` into a vector.

				// To mask insertions via AND.
				reinsert_mask: S8 := <S8>(reinsert << (63-IOTA)) >> 63; // -1 if reinsert bit is set, otherwise 0.
				// 2. update register's position.
				// TODO: go through all cases, ensure correct values. Find good formula taking into account compile-time evaluation for simplification.
				Positions[i][IT] := (reinsert_mask & ###TempRegName) - 1; // if reg == 15 (NOP): assign whatever, dummy column. If reg and reinsert: set to insert pos. Otherwise, we want to set it to the default value (-1) to indicate that it is not there.

				insertPos ::= 4*###TempRegName;
				insert: U8 := (~IT & reinsert_mask) << insertPos; // on reinsert: ~reg. Otherwise, 0. If NOP: 0.

				// 3. push down the queue and insert the register at the top.
				maskNewer ::= newerMasks[pos & 0xf]; // mask off the potential -1.
				low ::= Queue[i] &~ maskNewer;
				high ::= (Queue[i] ^ insert) >> 4 & maskNewer;
				Queue[i] := (low | high);
			}
		}

		spill(nop: U8, spilled: U8[N] &) VOID {
			|||{spilled} {
				//STATIC x: @(SIMD) U8[x];

				|||{Positions[IOTA]} IT -= (IT > 0);
				IT := 0xf &~ Queue[i];
				Queue[i] >>= 4;
			}
		}
	}
}
// This is one of the central workhorses of the compiler. We want to put this into static memory and not use pointer indirection in here, whenever possible.
::rlc::codegen::x86::dumb Generator
{
	{}:
		Temporaries (NOINIT),
		UnpatchedJump (NOINIT),
		Scopes (NOINIT);

	CommandBuffer: RAW[]; // Must be "large enough".
	CommandProgress: U4;
	TemporaryCount: U2;
	Stack: StackFrame;
	Temporaries: Temporary[0xffff];
	UnpatchedJumps: UnpatchedJump[0xffff];

	[size: NUMBER; Int]bytes(opcode: Int) VOID -- {
		CommandBuffer[CommandProgress] := opcode;
		CommandProgress += size;
	}

	// DECLARE LOCALS
	alloc_temporary_r1(id: U2, weight: U2) VOID --
		{ Temporaries[id] := (weight, 1, 255, -<S4>(MaxStack)-1); MaxStack += 1; }
	alloc_temporary_r2(id: U2, weight: U2) VOID --
		{ Temporaries[id] := (weight, 2, 255, -<S4>(MaxStack)-2); MaxStack += 2; }
	alloc_temporary_r4(id: U2, weight: U2) VOID --
		{ Temporaries[id] := (weight, 4, 255, -<S4>(MaxStack)-4); MaxStack += 4; }
	alloc_temporary_r8(id: U2, weight: U2) VOID --
		{ Temporaries[id] := (weight, 8, 255, -<S4>(MaxStack)-8); MaxStack += 8; }

	// LOAD A0-A2 from immediate constant.
	/// MOV r8(d), imm32/imm64
	load_a0_imm_u1(imm: U1) VOID -- { load_a0_imm_u4(imm); }
	load_a0_imm_u2(imm: U2) VOID -- { load_a0_imm_u4(imm); }
	load_a0_imm_u4(imm: U4) VOID -- { [#2]bytes(0r41B8); [#4]bytes(imm); }
	load_a0_imm_u8(imm: U8) VOID -- { [#2]bytes(0r49B8); [#8]bytes(imm); }

	load_a1_imm_u1(imm: U1) VOID -- { load_a1_imm_u4(imm); }
	load_a1_imm_u2(imm: U2) VOID -- { load_a1_imm_u4(imm); }
	load_a1_imm_u4(imm: U4) VOID -- { [#2]bytes(0r41B9); [#4]bytes(imm); }
	load_a1_imm_u8(imm: U8) VOID -- { [#2]bytes(0r49B9); [#8]bytes(imm); }

	load_a2_imm_u1(imm: U1) VOID -- { load_a2_imm_u4(imm); }
	load_a2_imm_u2(imm: U2) VOID -- { load_a2_imm_u4(imm); }
	load_a2_imm_u4(imm: U4) VOID -- { [#2]bytes(0r41BA); [#4]bytes(imm); }
	load_a2_imm_u8(imm: U8) VOID -- { [#2]bytes(0r49BA); [#8]bytes(imm); }

	// LOAD A0-A2 from local variable -- there is also a imm8 offset version...
	// We always load a zero/sign extended U8. We never operate on small values.
	localaddr(id: U2) VOID -- { [#4]bytes(Temporaries[id].Stack); }
	/// MOVZX r8d, byte/word [rbp+imm32]
	/// MOV r8d/r8d, [rbp+imm32]
	load_a0_local_u1(id: U2) VOID -- { [#4]bytes(0r440FB685); localaddr(id); }
	load_a0_local_u2(id: U2) VOID -- { [#4]bytes(0r440FB785); localaddr(id); }
	load_a0_local_u4(id: U2) VOID -- { [#3]bytes(0r448B8500); localaddr(id); }
	load_a0_local_8(id: U2) VOID --  { [#3]bytes(0r4C8B8500); localaddr(id); }

	load_a1_local_u1(id: U2) VOID -- { [#4]bytes(0r440FB68D); localaddr(id); }
	load_a1_local_u2(id: U2) VOID -- { [#4]bytes(0r440FB78D); localaddr(id); }
	load_a1_local_u4(id: U2) VOID -- { [#3]bytes(0r448B8D00); localaddr(id); }
	load_a1_local_8(id: U2) VOID --  { [#3]bytes(0r4C8B8D00); localaddr(id); }

	load_a2_local_u1(id: U2) VOID -- { [#4]bytes(0r440FB695); localaddr(id); }
	load_a2_local_u2(id: U2) VOID -- { [#4]bytes(0r440FB795); localaddr(id); }
	load_a2_local_u4(id: U2) VOID -- { [#3]bytes(0r448B9500); localaddr(id); }
	load_a2_local_8(id: U2) VOID --  { [#3]bytes(0r4C8b9500); localaddr(id); }

	/// MOVSX r8, byte/word/dword
	load_a0_local_s1(id: U2) VOID -- { [#4]bytes(0r4C0FBE85); localaddr(id); }
	load_a0_local_s2(id: U2) VOID -- { [#4]bytes(0r4C0FBF85); localaddr(id); }
	load_a0_local_s4(id: U2) VOID -- { [#3]bytes(0r4C638500); localaddr(id); }

	load_a1_local_s1(id: U2) VOID -- { [#4]bytes(0r4C0FBE8D); localaddr(id); }
	load_a1_local_s2(id: U2) VOID -- { [#4]bytes(0r4C0FBF8D); localaddr(id); }
	load_a1_local_s4(id: U2) VOID -- { [#3]bytes(0r4C638D00); localaddr(id); }

	load_a2_local_s1(id: U2) VOID -- { [#4]bytes(0r4C0FBE95); localaddr(id); }
	load_a2_local_s2(id: U2) VOID -- { [#4]bytes(0r4C0FBF95); localaddr(id); }
	load_a2_local_s4(id: U2) VOID -- { [#3]bytes(0r4C639500); localaddr(id); }

	// STORE A0-A2 to local variable -- there is also an imm8 variant
	store_a0_local_1(id: U2) VOID -- { [#3]bytes(0r44888500); localaddr(id); }
	store_a0_local_2(id: U2) VOID -- { [#4]bytes(0r66448985); localaddr(id); }
	store_a0_local_4(id: U2) VOID -- { [#3]bytes(0r44898500); localaddr(id); }
	store_a0_local_8(id: U2) VOID -- { [#3]bytes(0r4C898500); localaddr(id); }

	store_a1_local_1(id: U2) VOID -- { [#3]bytes(0r44888D00); localaddr(id); }
	store_a1_local_2(id: U2) VOID -- { [#4]bytes(0r6644898D); localaddr(id); }
	store_a1_local_4(id: U2) VOID -- { [#3]bytes(0r44898D00); localaddr(id); }
	store_a1_local_8(id: U2) VOID -- { [#3]bytes(0r4C898D00); localaddr(id); }

	store_a2_local_1(id: U2) VOID -- { [#3]bytes(0r44889500); localaddr(id); }
	store_a2_local_2(id: U2) VOID -- { [#4]bytes(0r66448995); localaddr(id); }
	store_a2_local_4(id: U2) VOID -- { [#3]bytes(0r44899500); localaddr(id); }
	store_a2_local_8(id: U2) VOID -- { [#3]bytes(0r4C899500); localaddr(id); }


	// INTEGER ARITHMETIC
	add() VOID -- { [#3]bytes(  0r4D01C800); }
	sub() VOID -- { [#3]bytes(  0r4D29C800); }

		// - Cannot use r8b, r9b, so we use: mov rax, r8; mul r9; mov r8, rax
		// this sucks, we may want to use rax, rbx, etc. instead, but will have to be wary of clobbering. But for now it is sufficient.
		// we ignore carry / overflow flags, so we just use unsigned for everything.
	mul() VOID -- { [#8]bytes(0r4C89C049F7E14989); [#1]bytes(0rC0); }

		// xor edx, edx; mov rax, r8; div r9; mov r9, rdx; mov r8, rax; -- primitive, but works for now. We don't really use division anyway.
	divmod_u() VOID -- { [#8]bytes(0r31D24C89C049F7F1); [#6]bytes(0r4989D14989C00000); }
	divmod_s() VOID -- { [#8]bytes(0r31D24C89C049F7F9); [#6]bytes(0r4989D14989C00000); }

	// COMPARISONS
	cmp() VOID --  { [#3]bytes(  0r4D39C800); }
	test() VOID -- { [#3]bytes(  0r4D85C800); }

	// - BOOL comparisons (yielding a concrete value).
	// - xor rax, rax; cmp/test r8, r9; setcc al; mov r8, rax;
	// IR: needs to differentiate between flags/branching comparison and comparisons as values. Maybe classify as multiple potential things, and then revisit and clarify later on. It can then be put into a lookup or something (inside the codegen) to turn it into a concrete single-value switch.
	// IR: Also needs to differentiate between uses of bools, like adding (adc), multiplying (movcc), etc., as this affects how they get generated.
	rax0() VOID -- { [#2]bytes(0r31C0); }
	a0_rax() VOID -- { [#3]bytes(0r4989C000); }
	bool_l_u() VOID -- { rax0(); cmp(); [#3]bytes(0r0F92C000); a0_rax(); }
	bool_l_s() VOID -- { rax0(); cmp(); [#3]bytes(0r0F9CC000); a0_rax(); }
	bool_le_u() VOID -- { rax0(); cmp(); [#3]bytes(0r0F96C000); a0_rax(); }
	bool_le_s() VOID -- { rax0(); cmp(); [#3]bytes(0r0F9EC000); a0_rax(); }

	bool_g_u() VOID -- { rax0(); cmp(); [#3]bytes(0r0F97C000); a0_rax(); }
	bool_g_s() VOID -- { rax0(); cmp(); [#3]bytes(0r0F9FC000); a0_rax(); }

	bool_ge_u() VOID -- { rax0(); cmp(); [#3]bytes(0r0F93C000); a0_rax(); }
	bool_ge_s() VOID -- { rax0(); cmp(); [#3]bytes(0r0F9DC000); a0_rax(); }

	bool_e() VOID -- { rax0(); test_8(); [#3]bytes(0r0F94C000); a0_rax(); }
	bool_ne() VOID -- { rax0(); test_8(); [#3]bytes(0r0F95C000); a0_rax(); }

	// - IF comparisons (used for branching).
	//   Create a hole, start a new code block, patch & paste later.

		// - Insert a relative S4 offset that has to be closed again later via += CommandProgress.
	if_hole(id: U4) VOID --
	{
		UnpatchedJumps[id] := CommandProgress;
		[#4]bytes(-(CommandProgress+4));
	}

	if_l_u(id: U4) VOID -- { cmp(); [#2]bytes(0r0F82); if_hole(id); }
	if_l_s(id: U4) VOID -- { cmp(); [#2]bytes(0r0F8C); if_hole(id); }

	if_le_u(id: U4) VOID -- { cmp(); [#2]bytes(0r0F86); if_hole(id); }
	if_le_s(id: U4) VOID -- { cmp(); [#2]bytes(0r0F8E); if_hole(id); }

	if_g_u(id: U4) VOID -- { cmp(); [#2]bytes(0r0F87); if_hole(id); }
	if_g_s(id: U4) VOID -- { cmp(); [#2]bytes(0r0F8F); if_hole(id); }

	if_ge_u(id: U4) VOID -- { cmp(); [#2]bytes(0r0F83); if_hole(id); }
	if_ge_s(id: U4) VOID -- { cmp(); [#2]bytes(0r0F8D); if_hole(id); }

	if_e(id: U4) VOID -- { test(); [#2]bytes(0r0F84); if_hole(id); }
	if_ne(id: U4) VOID -- { test(); [#2]bytes(0r0F85); if_hole(id); }

	/// test r8, r8; jz/jnz near ...
	if_false(id: U4) VOID -- { [#5]bytes(0r4D85C00F84000000); if_hole(id); }
	if_true(id: U4) VOID --  { [#5]bytes(0r4D85C00F85000000); if_hole(id); }

	// CONTROL FLOW
	link_scope_end() VOID -- {
		scope: ?& := ScopeEnds.last();
		FOR(scope.Refs[FOR scope.RefCount])
			CommandBuffer[IT] += CommandProgress;
		scope.RefCount := 0;
	}

	else() VOID --
	{
		// Generate jump past the else.
		[#1]bytes(0rE9); // JMP near (S4 offset)
		ref ::= CommandProgress; // update patch reference
		[#4]bytes(-(CommandProgress + 4)); // patchable offset: needs += CommandProgress.

		link_scope_end(); // all jumps that wanted to get to the else, will go here.
		ScopeEnds.last() := ref; // reuse scope, register the jump from just now.
	}


	end_if() VOID --
	{
		link_scope_end();
		ScopeEnds.drop_back();
	}

	end_loop() VOID --
	{
		[#1]bytes(0rE9); // JMP NEAR
		[#4]bytes(ScopeEnds.last().Start-(CommandProgress + 4)); // JMP NEAR .start
		CommandBuffer[ScopeEnds.last()] += CommandProgress; // patch LOOP jmp.
	}


	return() VOID -- { [#2]bytes(0rC9C3); } // leave; ret

	// at the end of the function, we insert this. We need empty stackframe support for recursion.
	enter() VOID -- {
		IF(!MaxStack) RETURN;
		IF(MaxStack <= 0xffff)
		{
			// enter MaxStack, 0
			[#1]bytes(0rC8);
			[#2]bytes(<U2>(MaxStack));
			[#1]bytes(0r00);
		} ELSE
		{
			// push rbp; mov rbp, rsp; sub rsp, MaxStack
			[#7]bytes(0r554889E54881EC00);
			[#4]bytes(MaxStack);
		}
	}

	pass_arg_a0_1() VOID -- { pass_arg_a0_2(); }
	pass_arg_a0_2() VOID -- { [#3]bytes(0r66415000); }
	pass_arg_a0_4() VOID -- { pass_arg_a0_8(); }
	pass_arg_a0_8() VOID -- { [#2]bytes(0r4150); }

	pass_arg_imm_s1(imm: S1) VOID -- { [#2]bytes(0r6641); [#1]bytes(imm); }
	pass_arg_imm_s2(imm: S2) VOID -- { [#2]bytes(0r6668); [#2]bytes(imm); }
	pass_arg_imm_s4(imm: S4) VOID -- { [#1]bytes(0r68); [#4]bytes(imm); }
	pass_arg_imm_8(imm: S8) VOID -- { [#2]bytes(0r48b8); [#8]bytes(imm); [#1]bytes(0x50); } // mov rax, ...; push rax
}


// We might need two steps of code generation to properly solve register allocation and stack allocation, as it is ISA-specific whether a value takes up stack space at all, when it spills, how well it can cope with peaks, etc. So, the IR code gives us an agnostically optimised version of the code (eliminating constants, simplifying expressions, etc.), and we then try to optimise it once more for register allocation. Also, some operations may spill or clobber registers differently on different ISAs. And the operations performed on a value may prompt us to migrate it between registers temporarily or change the allocation entirely -- the same for what operations produced a value to begin with.

(/ Generally, we have to differentiate between:
	- one-use values (like numbers)
	- addressable values (need to be spilled before address is taken, at least if a potential read/write follows; otherwise, it just needs to have an address -- not sure whether that is actually meaningful, though.
	- parameters
	- multi-use, unaddressed values (as soon as it uses non-inlined member calls, it is addressed; but inlined member calls can avoid that) /)

(/ So, we have multiple options for code generation:
	- Dumbest possible -O0 type,
	- Trivial register allocation,
	- multi-pass register allocation,
	- computation code optimisation (latency, throughput, interleaving, etc. -- although this is orthogonal to the rest, and maybe should be a separate option)
We can offer different performance options as compiler flags. These also affect the IR, potentially. If we just want to be super quick to compile, but do not care about quality of the code, the IR can also do much less work, potentially. /)

// Task: Generate the dumbest code with as little effort as possible.
// - We need to track temporaries and locals, but we do not need to allocate registers. We directly take everything from stack and write it right back. But we should probably do the simple thing where we at least make use of r11-r15 in a greedy manner. There is no fundamental difference between locals and temporaries, although we should use per-statement scopes for temporaries, which can reset the stack capacity so that we can reuse stack slots.
// - 
// - We use rel32 calls because why not. Actually easier anyway.
// - We use a0-2: r8-10, because they never get clobbered, so it is easier to write correct code.
// - We only use 64-bit values when computing. All values get sign-extended or zero-extended to full size.



(/ Stack rules:
	- Everything gets allocated into registers first.
	- If registers are full, spill LRU to stack.
	- Loading into a register makes that stack slot available to others.
	- When we enter a new scope, we do not want to auto-spill all old values.
	- When we spill outer values into an inner scope, we need to keep track of that. But only registers can spill to begin with, so per scope, we have a fixed upper bound on how many can be spilled. We only need to iterate per scope, not over all locals, to find all boundary-crossing spills.
		- This means: scopes are not hard boundaries, and we can make perfect use of stack space across scopes because everything can spill everywhere.
		- Result values need to be allocated before a scope starts.
		- Closing a scope: iterate over all temporaries declared within that scope; clear them. Load all boundary-crossing spills that are in that scope into registers? Re-spill them? That would be costly. Maybe we can keep them as-is, because peak usage already happened anyway. We would only need a defragmentation if we wanted to do a coroutine. We also do not want to migrate values on the stack that were declared outside an IF statement or any other branching statement. Thus, we need to track whether we are in a branch or main statement. Only the main flow is allowed to migrate values (actually, only the flow that declared it, so within an if, we can still migrate its own values). Some values cannot be migrated, for example arrays or variables to which a pointer exists. /)


// TODO: we need to patch up return statements (whether they should include a LEAVE or not).
(/ Additionally, we also need to take care of destructors and exceptions. For that, we want to allow a scope to exit either normally or via return/throw.
	- IR registers destructors in codegen scopes.
		- Do not register nop destructors (task of the IR generator).
	- Destructors are on the happy path
	- Allow jumping straight into the destructors for nonstandard termination.
		- We need multiple jump points, or we need lots of nested scopes.
		- The IR should announce whenever a lifetime with a destructor starts, and it should also tell us which destructor nesting to jump to.
		- The IR should also manually make us generate the destructor code including all optimisations / eliminations / inlinings.
		=> all we need is placeholders to jump to.
		=> the codegen actually does not really need awareness of scopes. It only needs to be told what to do. The IR may have to tell us what kind of jumps there are, though, in case some codegen backend is not using jumps, but structured code instead (RISA/RASM).
		=> IR tells us to make a jump that gets patched later, and what kind of jump it is. It also tells us when to patch which kind of jump, giving IDs to those. Then, one array of unpatched jump locations is sufficient, instead of one array per scope nesting. Scope nestings no longer really exist, then (in the code generator).
	- At the end of destructors, if RCX is zero (or nonzero), use JRCXZ to jump to the next destructor block, while preserving RCX.
		- We can use RCX as exception pointer, or just as status indicator for termination. Then we can use additional registers for storing type info, etc.
			- If RCX is "return", at the final scope end, we clear it, so that we do not continue returning. If it is "throw", we leave it as-is. It could also have other modes maybe that can do other stuff, such as profiling? But since RCX always indicates normal/abnormal execution, maybe we do not want to put normal stuff like profiling in there. Or maybe it counts as abnormal.
		- Since we have full control over what registers get used, we can also use some SIMD registers for additional permanent hot storage. This could actually be a good solution for template code, as we can put template parameters into these registers, and then avoid code duplication. This also allows us to instantiate new templates at runtime, if needed (although they can't full inline, then).
			- We should be able to expect the presence of both XMM0-7, as well as XMM8-15, but not the YMM registers as a baseline, if we want to activate vector registers at all.
			- We definitely can expect the MMX registers, but then we have to wrangle them if floats ever get used.
			- according to https://stackoverflow.com/questions/44018590/128-bit-values-from-xmm-registers-to-general-purpose, the higher half of an xmm register (pextrq) is slow to access, being roughly as fast as a L1 cache access, but the lower half is definitely faster (mov rax, xmm0). Pextrq needs SSE4.1, not SSE4a, so my old tower can't run that. We can use punpckhqdq to extract the XMM high word into another XMM low word, and then move out of that. So we would need one XMM clobber register. Additionally, we want  So we can have 8-16 sets of very hot state, and another set of slightly less hot state, but still guaranteeing L1-tier performance. Maybe the lower half could contain constants (like for templates) that have frequent use, and the upper half could have stuff that does not need as frequent access.
		- Also use RCX for the ? operator (expression abort / ELSE operator) /)