INCLUDE "../../tokeniser/tokeniser.rl"
INCLUDE 'std/map'
INCLUDE 'std/hash'

::rlc::compiler CodeTokeniser
{
	STATIC name() CHAR#[#] -- := "code tokeniser";

	Input
	{
		Contents:    CHAR#[#];
		StartOffset: U4;
		File:        src::File;
		IsDummy:     BOOL;

		{...};
	}
	Output {
		Tokens: @(CACHELINE) tok::FileTokenView;
		File:                src::File;
		IdToks: {U4, U4}-std::Vec;
		IsDummy: BOOL;

		{...};
	}

	HotsAlloc: std::temp::Alloc;
	PayloadsAlloc: std::temp::Alloc;
	PositionsAlloc: std::temp::Alloc;

	// over-allocated, but should not be a problem.
	fileClassificationBuffer: U1[#];

	{}:
		HotsAlloc      := :custom(SIZEOF(tok::TokenHot) * MI, SIZEOF(tok::TokenHot) * MI),
		PayloadsAlloc  := :custom(SIZEOF(tok::Payload)  * MI, SIZEOF(tok::Payload)  * MI),
		PositionsAlloc := :custom(SIZEOF(tok::Position) * MI, SIZEOF(tok::Position) * MI),
		fileClassificationBuffer := std::heap::alloc.[U1]alloc_array(1 * MI);

	[T]
	STATIC grow_array(alloc: std::temp::Alloc &, old_array: T![] &, old: U4, new_array_size: U4) VOID
	{
		grow_by ::= (new_array_size - old);
		IF(alloc.try_grow_last_allocation_by(grow_by * SIZEOF(T)))
			RETURN;

		new_arr: T[];
		[T]alloc_array(alloc, new_arr, new_array_size);
		FOR(old_array[FOR old])
			new_arr[IOTA].{ IT };
		old_array := new_arr;
	}

	[T]
	STATIC alloc_array(alloc: std::temp::Alloc &, array: T![] &, size: U4) VOID --
	{
		align ::= ALIGNOF(T);
		IF#(align<CACHELINE)
			align := CACHELINE;
		array := <T *>(alloc.alloc_raw(size * SIZEOF(T), align))[];
	}

	Timings: tok::Tokeniser::TimingTracker;

	handle_job(
		input: Input &,
		output: Output *,
		U4
	) {BOOL, U4}
	{
		output->File := input.File;
		output->IsDummy := input.IsDummy;

		// This should ensure we do not have a relocation in a file.
		capacity ::= 256 * KI;
		alloc_array(HotsAlloc,      output->Tokens.Hots,      capacity);
		alloc_array(PayloadsAlloc,  output->Tokens.Payloads,  capacity);
		alloc_array(PositionsAlloc, output->Tokens.Positions, capacity);

		output->Tokens.TokenCount := 0;

		ASSERT(##input.Contents < ##fileClassificationBuffer);

		FOR(input.Contents)
			fileClassificationBuffer[][IOTA] := tok::Tokeniser::classifier_lut[<U1>(IT)];
		FOR(fileClassificationBuffer[FROM ##input.Contents FOR 64])
			IT := tok::Tokeniser::classifier_lut['\000'];

		tokeniser: tok::Tokeniser(input.File, input.Contents, input.StartOffset);
		tokeniser.Classifiers := fileClassificationBuffer[];
		tokeniser.Timings := Timings;

		// Job 1: tokenise the file. -- this needs to be twice as fast to sustain the speed at which the SSD can read files. Having this disabled has 1.0ms+ for loading 50 files. Having it enabled has 2.0ms+ for loading 50 files (1 thread), and more like 3-4ms.

		// Continue tokenising the files.
		WHILE(tokeniser.parse_all(&output->Tokens, capacity))
		{
			old ::= capacity;
			capacity *= 2;

			grow_array(HotsAlloc,      output->Tokens.Hots,      old, capacity);
			grow_array(PayloadsAlloc,  output->Tokens.Payloads,  old, capacity);
			grow_array(PositionsAlloc, output->Tokens.Positions, old, capacity);
		}
		output->Tokens += <tok::Token>(:EOF);

		IF!(input.IsDummy)
			Timings := tokeniser.Timings;

		// Reset allocator to the actual allocation size.
		overshoot ::= capacity - ##output->Tokens;
		HotsAlloc.shrink_last_allocation_by(overshoot * SIZEOF(tok::TokenHot));
		PayloadsAlloc.shrink_last_allocation_by(overshoot * SIZEOF(tok::Payload));
		PositionsAlloc.shrink_last_allocation_by(overshoot * SIZEOF(tok::Position));

		= (!input.IsDummy, input.File);
	}
}