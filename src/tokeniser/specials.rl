::rlc::tok
{
	UNION SpecialStorage { Word: U4; Chars: CHAR[4]; }

	UNION SpecialU {
		PrefixOp: PrefixOperator;
		PostfixOp: PostfixOperator;
		PrefixOrPostfixOp: PrefixOrPostfixOperator;
		PrefixOrBinaryOp: PrefixOrBinaryOperator;
		BinaryOp: BinaryOperator;
		AssignmentOp: AssignmentOperator;
		Punctuation: tok::Punctuation;
		FlowControlKw: tok::FlowControlKeyword;
	}
	special_to_tok_type: ENUM tok::Type[TABLE ENUM SpecialU](
		:PrefixOp(:PrefixOp),
		:PostfixOp(:PostfixOp),
		:PrefixOrPostfixOp(:PrefixOrPostfixOp),
		:PrefixOrBinaryOp(:PrefixOrBinaryOp),
		:BinaryOp(:BinaryOp),
		:AssignmentOp(:AssignmentOp),
		:Punctuation(:Punctuation),
		:FlowControlKw(:FlowControl)
	);

	specials_list: {CHAR#[#], TAGGED SpecialU}[?](
		("+=", :AssignmentOp(:plusEqual)),
		("++", :PrefixOrPostfixOp(:doublePlus)),
		("+", :PrefixOrBinaryOp(:plus)),

		("-=", :AssignmentOp(:minusEqual)),
		("-:", :PrefixOp(:minusColon)),
		("--", :PrefixOrPostfixOp(:doubleMinus)),
		("->*", :BinaryOp(:minusGreaterAsterisk)),
		("->", :BinaryOp(:minusGreater)),
		("-", :PrefixOrBinaryOp(:minus)),

		("*=", :AssignmentOp(:asteriskEqual)),
		("*", :PrefixOrBinaryOp(:asterisk)),

		("\\", :PrefixOp(:backslash)),

		("/=", :AssignmentOp(:forwardSlashEqual)),
		("/", :BinaryOp(:forwardSlash)),

		("%=", :AssignmentOp(:percentEqual)),
		("%", :BinaryOp(:percent)),

		("!=", :BinaryOp(:exclamationMarkEqual)),
		("!:", :PrefixOp(:exclamationMarkColon)),
		("!", :PrefixOrPostfixOp(:exclamationMark)),

		("^=", :AssignmentOp(:circumflexEqual)),
		("^", :BinaryOp(:circumflex)),

		("~:", :PrefixOp(:tildeColon)),
		("~", :PrefixOp(:tilde)),

		("&&&", :PrefixOp(:tripleAmp)),
		("&&=", :AssignmentOp(:doubleAmpEqual)),
		("&&", :PrefixOrBinaryOp(:doubleAmp)),
		("&=", :AssignmentOp(:ampEqual)),
		("&", :PrefixOrBinaryOp(:amp)),

		("||=", :AssignmentOp(:doublePipeEqual)),
		("||", :BinaryOp(:doublePipe)),
		("|=", :AssignmentOp(:pipeEqual)),
		("|", :BinaryOp(:pipe)),

		("?""?", :Punctuation(:doubleQuestionMark)),
		("?", :PostfixOp(:questionMark)),

		("::=", :Punctuation(:doubleColonEqual)),
		(":=", :Punctuation(:colonEqual)),
		("::", :Punctuation(:doubleColon)),
		(":", :Punctuation(:colon)),

		("@", :Punctuation(:at)),

		("...", :Punctuation(:tripleDot)),
		(".*", :BinaryOp(:dotAsterisk)),
		(".", :BinaryOp(:dot)),

		(",", :Punctuation(:comma)),
		
		(";", :Punctuation(:semicolon)),
		
		("==", :BinaryOp(:doubleEqual)),
		//("=>", :BinaryOp(:equalGreater)),
		("=", :FlowControlKw(:equal)),

		("[", :Punctuation(:bracketOpen)),
		("]", :Punctuation(:bracketClose)),
		("{", :Punctuation(:braceOpen)),
		("}", :Punctuation(:braceClose)),
		("(", :Punctuation(:parentheseOpen)),
		(")", :Punctuation(:parentheseClose)),

		("<<<=", :AssignmentOp(:tripleLessEqual)),
		("<<<", :BinaryOp(:tripleLess)),
		("<<=", :AssignmentOp(:doubleLessEqual)),
		("<<", :BinaryOp(:doubleLess)),
		("<=", :BinaryOp(:lessEqual)),
		("<>", :BinaryOp(:lessGreater)),
		//("<-", :PrefixOp(:lessMinus)),
		("<", :BinaryOp(:less)),

		(">>>=", :AssignmentOp(:tripleGreaterEqual)),
		(">>>", :BinaryOp(:tripleGreater)),
		(">>=", :AssignmentOp(:doubleGreaterEqual)),
		(">>", :BinaryOp(:doubleGreater)),
		(">=", :BinaryOp(:greaterEqual)),
		(">", :BinaryOp(:greater)),

		("$", :Punctuation(:dollar)),
		("##", :PrefixOp(:doubleHash)),
		("#", :Punctuation(:hash))
	);

	specials_storage: {U4, U4, ENUM tok::Type, U1}[##specials_list] (NOINIT);
	specials_lut: {U4, U4, ENUM tok::Type, U1}#[#][128] (NOINIT);

	init_specials_lut() VOID
	{
		ASSERT(##specials_storage == ##specials_list);
		specials_lut := (NULL);

		start: U1 := 0;
		startc: UCHAR := specials_list[0].(0)[0];

		FOR(specials_list)
		{
			storage: SpecialStorage := :Word(0);
			string ::= IT.(0);
			enum ::= IT.(1);
			FOR(i ::= 0; i < ##string; i++)
				storage.Chars[i] := string[i];

			specials_storage[IOTA].(0) := storage.Word;
			specials_storage[IOTA].(1) := <U4>(0xFFFFFFFF) >> (32 - 8 * ##string);
			specials_storage[IOTA].(2) := special_to_tok_type[enum.(0)];
			specials_storage[IOTA].(3) := <U1>(enum.(1).PrefixOp);

			IF(startc != string[0]) {
				specials_lut[startc] := specials_storage[FROM start UNTIL IOTA];
				start := IOTA;
				startc := string[0];
			}
		}
		specials_lut[startc] := specials_storage[FROM start];
	}
}