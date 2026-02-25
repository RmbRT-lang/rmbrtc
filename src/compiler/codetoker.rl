INCLUDE "../tokeniser/tokeniser.rl"
INCLUDE 'std/map'
INCLUDE 'std/hash'

::rlc::compiler CodeTokeniser
{
	STATIC name() CHAR#[#] -- := "code tokeniser";

	Input
	{
		Tokeniser: @(CACHELINE) tok::Tokeniser;
		First:                  tok::Token;
		File:                   src::File;

		{...};
	}
	Output {
		Tokens: @(CACHELINE) tok::FileTokens;
		File:                src::File;
		Identifiers:         CHAR#[#] -std::Vec;
		IdHashes:            U8       -std::Vec;

		{...};
	}

	IdToks: {U4, U4}-std::Vec;
	IdStrs: std::[{U8, std::str::CV}; U2]Map[16]; // len % 16
	IdStrSet: CHAR#[#]-std::Vec;


	[#kN] // Returns a bitmap of whether an entry was found.
	STATIC multi_find_by_hash(
		map: std::[{U8, std::str::CV}; U2]Pair[#],
		hashes: U8[],
		locs: U4[]
	) U4 --
	{
		count ::= ##map;

		rs_: U4[kN] := ##map; rs # ::= rs_[];
		ls_: U4[kN]; ls # ::= ls_[];

		found: U4 := 0;
		WHILE(count)
		{
			count >>= 1;
			|||{kN}
			{
				l ::= ls[IOTA];
				r ::= rs[IOTA];
				mid ::= (l + r)>>1;
				n ::= mid+1;
				midkey ::= map[][mid].Key.(0);
				hash ::= hashes[IOTA];

				r[IOTA] := (midkey > hash) ?? mid : r;
				l[IOTA] := (midkey < hash) ?? n : l;
				found   |= (midkey == hash) << IOTA;
			}
		}

		|||{kN} locs[IOTA] := (ls[IOTA] + rs[IOTA]) >> 1;

		= found;
	}

	handle_job(
		input: Input &,
		output: Output *
	) VOID
	{

		output->Tokens.clear_reuse();
		output->Tokens.reserve(4 * 1024);
		output->File := input.File;
		output->Identifiers.clear_reuse();
		output->Identifiers.reserve(4096);
		output->IdHashes.clear_reuse();
		output->IdHashes.reserve(4096);

		// We chunk identifiers based on length. This lets us cut down on relocation size. Or we do not even use ordered sets at all. Then we can just do linear searches.
		FOR(IdStrs)
		{
			IT.clear_reuse();
			IT.reserve(1024);
		}

		IdToks.clear_reuse();
		IdToks.reserve(16<<10);

		IdStrSet.clear_reuse();
		IdStrSet.reserve(16<<10);

		// Job 1: tokenise the file. -- this needs to be twice as fast to sustain the speed at which the SSD can read files. Having this disabled has 1.0ms+ for loading 50 files. Having it enabled has 2.0ms+ for loading 50 files (1 thread), and more like 3-4ms.

		tokId: U4 := 0;
		// Continue tokenising the files.
		DO(token ::= input.First)
		{
			output->Tokens += token;
			IF(token.Type == :Identifier)
				IdToks += (tokId, token.Length);
			++tokId;
		} WHILE(input.Tokeniser.parse_next(&token))
		output->Tokens += <tok::Token>(:EOF);


		// Job 2: dedup the identifiers. -- this completely kills performance. Having this enabled gives us ~5ms for 50 files (with 2 threads). Even adding multiple threads somehow doesn't improve performance, but actually decreases it. Must be horrible cache usage or something.
		// If we push this straight into the global identifier deduplicator, we have less work to do, although we also lose the per-file ID, which is important for smaller LUTs. We definitely need a portable version of the identifierPool or something. Or, during insertion of identifiers into the global pool, we also maintain a 64Kbit LUT which we fill up with the deduplicated IDs, and if it is a new hit, we know we had a new distinct identifier in this file. So this stage can prepare the tables, since the deduplicator stage cannot be parallelised. The per-file LUT only needs to be as large as the number of identifiers we have in this file, or 64K at most.
		f ::= input.File;
		strcount: U4 := 0;

		idents ::= &output->Identifiers;
		idhashes ::= &output->IdHashes;
		FOR(IdToks!)
		{
			IF(idents->Capacity <= strcount)
			{
				idents->reserve(strcount+1024);
				idhashes->reserve(strcount+1024);
			}

			idtok_i ::= IT.(0);
			tokLen ::= IT.(1);
			str ::= <src::Span>(output->Tokens.Positions![][idtok_i], tokLen).contents(f);
			(*idents)![][strcount] := str;
			
			hash ::= std::hash_str(str);
			(*idhashes)![][strcount] := hash;

			entry: {U8, CHAR#[#]} := (hash, str);
			ident_id ::= IdStrs[##str & (##IdStrs-1)].ensure(entry, strcount);

			strcount += ident_id == strcount;
			output->Tokens.Hots[idtok_i].SType.Identifier := ident_id;
		}
		output->Identifiers.set_size_ok(strcount);
		output->IdHashes.set_size_ok(strcount);
	}
}