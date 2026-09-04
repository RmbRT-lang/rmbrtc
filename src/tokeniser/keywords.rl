::rlc::tok
{
	UNION KeywordStorage { Words: U8[2]; Chars: CHAR[16]; }

	Keyword { Text: KeywordStorage; Kw: tok::Type; {...}; }

	keyword_storage: {KeywordStorage, ENUM tok::Type, U2}[
		###tok::DeclarationKeyword +
		###tok::BuiltinType +
		###tok::FlowControlKeyword +
		###tok::AuxKeyword +
		###tok::RegionKeyword +
		###tok::IntrinsicOperatorKeyword] (NOINIT);
	keyword_lut: {KeywordStorage, ENUM tok::Type, U2}[#][26] (NOINIT);

	to_upper(x: CHAR) CHAR -- := (x >= 'a' && x <= 'z') ?? x - ('a' - 'A') : x;

	[Enum] start_letters(count: U2[26] &) VOID --
	{
		FOR(###Enum)
			count[to_upper(*<CHAR #*>(<Enum>(IOTA))) - 'A'] += 1;
	}

	[Enum] fill_letters(count: U2[26] &, type: ENUM tok::Type) VOID --
	{
		FOR(###Enum)
		{
			name_str ::= <CHAR #*>(<Enum>(IOTA));
			first ::= to_upper(name_str[0]) - 'A';
			idx ::= count[first]++;

			len ::= std::str::len(name_str[]);
			ASSERT(len <= SIZEOF(KeywordStorage));

			storage ::= &keyword_storage[idx];
			storage->(0) := :Words(0);
			storage->(1) := type;
			storage->(2) := IOTA;

			FOR(len)
			{
				c ::= to_upper(name_str[IOTA]);
				storage->(0).Chars[IOTA] := c;
			}
		}
	}

	// keywords are the uppercase text version of their symbolic names.
	init_keyword_lut() VOID {
		keyword_lut := NULL;
		letter_keywords_total: U2[26] := 0; // count of keywords with the same starting letter.

		// Count keywords per starting letter.
		[tok::DeclarationKeyword]start_letters(letter_keywords_total);
		[tok::BuiltinType]start_letters(letter_keywords_total);
		[tok::FlowControlKeyword]start_letters(letter_keywords_total);
		[tok::AuxKeyword]start_letters(letter_keywords_total);
		[tok::RegionKeyword]start_letters(letter_keywords_total);
		[tok::IntrinsicOperatorKeyword]start_letters(letter_keywords_total);

		accum ::= 0;
		FOR(letter_keywords_total)
		{
			// Convert to starting indices.
			count ::= IT;
			start ::= accum;
			IT := start;
			accum += count;

			// Register keyword range.
			keyword_lut[IOTA] := keyword_storage[FROM start FOR count];
		}

		[tok::DeclarationKeyword]fill_letters(letter_keywords_total, :Declaration);
		[tok::BuiltinType]fill_letters(letter_keywords_total, :BuiltinType);
		[tok::FlowControlKeyword]fill_letters(letter_keywords_total, :FlowControl);
		[tok::AuxKeyword]fill_letters(letter_keywords_total, :AuxKeyword);
		[tok::RegionKeyword]fill_letters(letter_keywords_total, :Region);
		[tok::IntrinsicOperatorKeyword]fill_letters(letter_keywords_total, :IntrinsicOp);
	}

	lookup_keyword(text: CHAR#[#], last_word_mask: U8) {ENUM tok::Type, U2} -- {
		// TODO PERFORMANCE: beide worte reingeben, und die partial maske.
		// TODO PERFORMANCE: keyword_lut aufspalten? hash? Man könnte basierend auf anfangsbuchstabe und länge das machen.
		// TODO PERFORMANCE: copy loop rausschmeißen.
		// Theoretisch können wir auch hier zwei Funktionen benutzen, eine für <=8 länge, eine für >8, mit separaten tabellen.
		IF(##text > SIZEOF(KeywordStorage))
			= (:Identifier, 0);

		last_word_mask := (last_word_mask & 0x0101010101010101) * 255;
		mask0: U8 := last_word_mask;
		mask1: U8 := last_word_mask;
		mask0 |= MASK(##text > 8);
		mask1 &= MASK(##text > 8);

		text_as_words: U8# * := <U8 #*>(<VOID #*>(text[]));

		a: U8 := text_as_words[0] & mask0;
		b: U8 := text_as_words[1] & mask1;

		type: ENUM tok::Type := :Identifier;
		payload: U2;
		FOR(keyword_lut[<U1>(a) - 'A'])
		{
			mismatch: BOOL := (a ^ IT.(0).Words[0]) | (b ^ IT.(0).Words[1]);
			IF!(mismatch)
			{
				= (IT.(1), IT.(2));
			}
		}

		= (:Identifier, 0);
	}
}