::rlc::tok
{
	UNION KeywordStorage { Words: U8[2]; Chars: CHAR[16]; }

	Keyword { Text: KeywordStorage; Kw: tok::Type; {...}; }
	UNION KeywordU
	{
		Decl: tok::DeclarationKeyword;
		BuiltinType: tok::BuiltinType;
		FlowControl: tok::FlowControlKeyword;
		Aux: tok::AuxKeyword;
		BinaryOperator: tok::BinaryOperator;
		IntrinsicOp: tok::IntrinsicOperatorKeyword;
	}

	keyword_u_to_token_type: ENUM tok::Type[TABLE ENUM KeywordU](
		:Decl (:Declaration),
		:BuiltinType (:BuiltinType),
		:FlowControl (:FlowControl),
		:Aux (:AuxKeyword),
		:BinaryOperator (:BinaryOp),
		:IntrinsicOp (:IntrinsicOp)
	);

	keywords: TAGGED tok::KeywordU#[?](
		:Decl(:abstract),
		:BinaryOperator(:and),
		:Aux(:assert),
		:Aux(:bare),
		:BuiltinType(:bool),
		:FlowControl(:break),
		:FlowControl(:catch),
		:BuiltinType(:char),
		:FlowControl(:continue),
		:IntrinsicOp(:copy_rtti),
		:FlowControl(:default),
		:Decl(:destructor),
		:FlowControl(:die),
		:FlowControl(:do),
		:FlowControl(:else),
		:Decl(:enum),
		:Decl(:export),
		:Decl(:extern),
		:Aux(:false),
		:Decl(:final),
		:FlowControl(:finally),
		:FlowControl(:for),
		:FlowControl(:if),
		:Aux(:include),
		:Aux(:inline),
		:BuiltinType(:int),
		:Decl(:mask),
		:Aux(:noinit),
		:Aux(:null),
		:Aux(:number),
		:BinaryOperator(:or),
		:Decl(:override),
		:Decl(:private),
		:Decl(:protected),
		:Decl(:public),
		:FlowControl(:return),
		:BuiltinType(:s1),
		:BuiltinType(:s2),
		:BuiltinType(:s4),
		:BuiltinType(:s8),
		:Aux(:sizeof),
		:BuiltinType(:sm),
		:Decl(:static),
		:FlowControl(:switch),
		:Decl(:test),
		:Aux(:this),
		:FlowControl(:throw),
		:Aux(:true),
		:FlowControl(:try),
		:Aux(:type),
		:BuiltinType(:u1),
		:BuiltinType(:u2),
		:BuiltinType(:u4),
		:BuiltinType(:u8),
		:BuiltinType(:uchar),
		:BuiltinType(:uint),
		:BuiltinType(:um),
		:Decl(:union),
		:Decl(:virtual),
		:Aux(:visit),
		:Aux(:void),
		:FlowControl(:while)
	);

	keyword_storage: {KeywordStorage, ENUM tok::Type, U2}[##keywords] (NOINIT);
	keyword_lut: {KeywordStorage, ENUM tok::Type, U2}[#][26] (NOINIT);

	to_upper(x: CHAR) CHAR -- := (x >= 'a' && x <= 'z') ?? x - ('a' - 'A') : x;

	// keywords are the uppercase text version of their symbolic names.
	init_keyword_lut() VOID {
		keyword_lut := NULL;

		letter ::= 'A';
		start_idx ::= 0;
		FOR(keywords)
		{
			name ::= <NameOfEnum>() VISIT>>(IT).Name;
			first ::= to_upper(name[0]);
			len ::= std::str::len(name);
			ASSERT(len <= SIZEOF(KeywordStorage));
			ASSERT(first >= letter);

			IF(first != letter)
			{
				ASSERT(letter >= 'A');
				ASSERT(letter <= 'Z');
				ASSERT(first > letter);
				ASSERT(first <= 'Z');
				keyword_lut[letter - 'A'] := keyword_storage[FROM start_idx UNTIL IOTA];
				start_idx := IOTA;
				letter := first;
			}

			storage ::= &keyword_storage[IOTA];
			storage->(0) := :Words(0);
			storage->(1) := keyword_u_to_token_type[IT.(0)];
			storage->(2) := <U2>(IT.(1).IntrinsicOp);

			FOR(len)
			{
				c ::= to_upper(name[IOTA]);
				storage->(0).Chars[IOTA] := c;
			}
		}

		keyword_lut[letter - 'A'] := keyword_storage[FROM start_idx];
	}

	lookup_keyword(text: CHAR#[#]) {ENUM tok::Type, U2} -- {
		ASSERT(##text);
		IF(##text > SIZEOF(KeywordStorage))
			= (:Identifier, 0);

		kw: KeywordStorage := :Words(>0,>0);
		FOR(text) kw.Chars[IOTA] := IT;
		a ::= kw.Words[0];
		b ::= kw.Words[1];

		type: ENUM tok::Type := :Identifier;
		payload: U2;
		FOR(keyword_lut[text[0] - 'A'])
		{
			match: BOOL := (a == IT.(0).Words[0]) & (b == IT.(0).Words[1]);
			type := match ?? IT.(1) : type;
			payload := match ?? IT.(2) : payload;
		}

		= (type, payload);
	}
}