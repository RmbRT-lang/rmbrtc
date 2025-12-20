::rlc::tok Numbers // Not yet in use. TODO: add character classification flags again, and then make number parsing branchless, and use a lookup table. Numbers should be packed and parsed in SIMD. This means we want to probably use packed hex for all numbers.
{
	HexChars { Chars: @(SIMD) CHAR[16]; }
	DecChars { Chars: @(SIMD) CHAR[20]; Index: U4; }
	OctChars { Chars: @(SIMD) CHAR[22]; Index: U4; }
	BinChars { Chars: @(SIMD) CHAR[64]; }

	Hex: HexChars - std::Vec; HexIdx: U4 - std::Vec;
	Dec: DecChars - std::Vec;
	Oct: OctChars - std::Vec;
	Bin: BinChars - std::Vec; BinIdx: U4 - std::Vec; 
	NumberTokenIndices: U4 - std::Vec;

	{}:
		Hex := :reserve(2048), HexIdx := :reserve(2048),
		Dec := :reserve(2048),
		Oct := :reserve(2048),
		Bin := :reserve(2048), BinIdx := :reserve(2048),
		Numbers := :reserve(2048);

	reset() VOID
	{
		Hex.clear_reuse();
		Dec.clear_reuse();
		Oct.clear_reuse();
		Bin.clear_reuse();
		Numbers.clear_reuse();
	}

	new_hex() CHAR[16] & --
	{
		entry: ?& := Hex.noinit_grow_one();
		entry.(1) := new_number();
		= entry.(0);
	}

	new_dec() CHAR[20] & --
	{
		entry: ?& := Dec.noinit_grow_one();
		entry.(1) := new_number();
		= entry.(0);
	}

	new_oct() CHAR[22] & --
	{
		entry: ?& := Oct.noinit_grow_one();
		entry.(1) := new_number();
		= entry.(0);
	}

	new_bin() CHAR[64] & --
	{
		entry: ?& := Bin.noinit_grow_one();
		entry.(1) := new_number();
		= entry.(0);
	}

	PRIVATE new_number() U4 -- { i ::= ##Numbers; Numbers.noinit_grow_one(); = i; }
}