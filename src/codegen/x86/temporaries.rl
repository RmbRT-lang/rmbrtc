::rlc::codegen::x86
{
	UNION TempLoc
	{
		r8;
		r9;
		r10;
		r11;
		r12;
		r13;
		r14;
		r15;
		rbx;
		rax;
		rcx;
		rdx;
		rdi;
		rsi;
	!?	stack: S4;
	}
	// Keep in sync with TempLoc!
	// This is a priority list for register allocations.
	// Can only support up to 15 registers (and a 16-th dummy value).
	ENUM TempRegName
	{
		r8, // We keep the rX registers first, because they never get clobbered by other instructions.
		r9,
		r10,
		r11,
		r12,
		r13,
		r14,
		r15,
		rbx, // We might want to choose a different priority for legacy registers.
		rax,
		rcx,
		rdx,
		rdi,
		rsi
	}

	// Tracks the per-register state.
	UNION TempReg {
	*	free;
	!?	temporary: U2; // Stores a temporary.
	}

	Temporary {
		Location: TAGGED TempLoc;
		{...};

		# stacked() BOOL -- := Location.(0) == :stack;
	}

	UnpatchedJump {
		ENUM Semantics { if, else, loop, destructors }
		ENUM OffsetType { rel32 }
		Meaning: Semantics;
		Type: OffsetType;
		Location: U4;
		{...};
	}
}