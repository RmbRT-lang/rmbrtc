::rlc::scoper
{
	Namespace {
		Names: Identifier[#, SIMD];
		Entries: TAGGED GlobalScopeEntry-std::Vec;
	}

	// Do we even need a global vs. member scope entry? We will see when we get to actually use it.
	UNION GlobalScopeEntry {
		Class: Class-Handle;
		Namespace: Namespace-Handle;
		Function: Function-Handle;
		Variable: GlobalVariable-Handle;
	}

	(// Use this to look up many things in one single scope, such as locals, or class members & templates. For batched lookups in multiple scopes, use hash tables.
	@param names:
		An unordered set of names. CAUTION: Must not contain duplicates.
	@param found_index:
		-1 if not found, otherwise, the index of the element. /)
	[#kN]
	find_linear(
		ids_to_find: @(SIMD) Identifier [kN] #&,
		names:               Identifier#[#],
		found_index: @(SIMD) U2         [kN] &) VOID
	{
		|||{ids_to_find}
		{
			search_name ::= IT;
			index: S2 := -1;
			// roughly 3 cycles per iteration, 8 values. Can execute 2-3 iterations simultaneously, probably, so 16-24 SISD iterations every 3 cycles, being 5-8 SISD iterations per cycle.
			FOR(names)
				index ^= MASK(IT == search_name) &~ IOTA;
			found_index[IOTA] := foundIndex;
		}
	}
}