::rlc::codegen::x86 RegFile {
	Used: U4; // bitfield: whether a register is in use.
	Regs: TempReg[###TempRegName];

	Oldest: TempRegName;
	Newest: TempRegName;
	Older: TempRegName[(###TempRegName)+1];
	Newer: TempRegName[(###TempRegName)+1];
	{}--:
		Oldest(>###TempRegName),
		Newest(>###TempRegName),
		Newer(>###TempRegName),
		Older(>###TempRegName);

	# used_loc(x: ENUM TempLoc) BOOL -- := Used & (1 << <U1>(x));
	# used(reg: TempRegName) BOOL -- := Used & (1 << <U1>(reg));

	# full() BOOL -- := Used == (1<<###TempRegName)-1;
	# empty() BOOL -- := !Used;
	# first_available() U1 -- := FIRST0POS Used;

	// Safe to use on unallocated registers, too.
	// CAUTION: Does NOT mark the register as unused. Only deletes it from the LRU list.
	PRIVATE unlink_lru(reg: TempRegName) VOID -- {
		// Eliminate reg from LRU history.
		newer ::= Newer[>reg]; // Newer, or ###TempRegName if newest or evicted
		older ::= Older[>reg]; // Older, or ###TempRegName if oldest or evicted
		// Starts out initially as ###TempRegName (Ctor).
		// If we are empty, this is a nop, as reg is never ###TempRegName.
		// If we are evicted, this is a nop, as it is only equal if we are empty.
		// If we evict the last element, this resets it to ###TempRegName.
		Oldest := Oldest == reg ?? newer : Oldest;
		Newest := Newest == reg ?? older : Newest;
		Newer[>older] := newer; // Newer, or ###TempRegName if newest or evicted
		Older[>newer] := older; // Older, or ###TempRegName if oldest or eviceted

		// Set dummy values so that we do not need an IF in touch().
		Newer[>reg] := >###TempRegName;
		Older[>reg] := >###TempRegName;
	}

	UNION Eviction {
	*	None; // must be the first field, so that BOOL -> ENUM conversion fits.
	!?	EvictedTemp: {TempRegName, U2};
	}

	// Make a version that writes it to a pointer and increments it if it did evict? Then we can directly produce a stream of only evictions.
	clobber(reg: TempRegName) TAGGED Eviction {
		// In case we have an eviction, record it properly.
		eviction: TAGGED Eviction (NOINIT);
		eviction.(0) := >used(reg);
		eviction.(1) := (reg, Regs[>reg].temporary);

		// Eliminate from usage bitfield.
		Used &= ~<U4>(1) <<< >reg; // BTR used, reg;   SETC eviction.(0)

		// Mark the register as unused.
		unlink_lru(reg);

		= eviction;
	}

	// Constant-time, fully branch-free insertion of a value, with optional eviction of the lest recently used value.
	// Returns the new register it lives in, as well as the possible eviction to handle.
	load_evicted_temp(tempId: U2) {TempRegName, TAGGED Eviction} {
		is_full ::= full();
		free_bit ::= FIRST0BIT Used;
		free_name: TempRegName := >POPCNT (free_bit-1);

		Used |= free_bit; // nop if full.

		// In case we have an eviction, record it properly.
		eviction: TAGGED Eviction (NOINIT);
		eviction.(0) := >is_full;
		eviction.(1) := (Oldest, Regs[Oldest].temporary);

		// touch the allocated register.
		touch(free_name);

		= (free_name, eviction);
	}

	load_evicted_temp_into(tempId: U2, reg: TempRegName) TAGGED Eviction --
	{ DIE;}

	// Constant-time, fully branch-free insertion or updating of a value.
	// Does NOT mark the register in "Used".
	// 
	// Should this be used by the codegen directly? We can skip some logic if we know that a value was not 
	touch(reg: TempRegName) VOID -- {
		// TODO: check whether we can remove some redundancy from evict(); insert();

		// make sure the register is properly removed from its old position.
		unlink_lru(reg);

		Newer[>Newest] := reg;
		Older[>reg] := Newest;
		Newest := reg;
		Oldest := (Oldest == >###TempRegName) ?? reg: Oldest;
	}
}