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
	special_to_tok_type: tok::Type[TABLE ENUM SpecialU](
		:PrefixOp(:prefixOperator),
		:PostfixOp(:postfixOperator),
		:PrefixOrPostfixOp(:prefixOrPostfixOperator),
		:PrefixOrBinaryOp(:prefixOrBinaryOperator),
		:BinaryOp(:binaryOperator),
		:AssignmentOp(:assignmentOperator),
		:Punctuation(:punctuation),
		:FlowControlKw(:flowControlKeyword)
	);

	(/specials_list: {CHAR#[#], TAGGED SpecialU}[?](
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
		("!", :PrefixOp(:exclamationMark)),

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
		(":=", :AssignmentOp(:colonEqual)),
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
		("##", :Punctuation(:doubleHash)),
		("#", :Punctuation(:hash))
	);/)

	specials_list_strings: CHAR#[#][?](
		"+=",
		"++",
		"+",
		"-=",
		"-:",
		"--",
		"->*",
		"->",
		"-",
		"*=",
		"*",
		"\\",

		"/=",
		"/",

		"%=",
		"%",

		"!=",
		"!:",
		"!",

		"^=",
		"^",

		"~:",
		"~",

		"&&&",
		"&&=",
		"&&",
		"&=",
		"&",

		"||=",
		"||",
		"|=",
		"|",

		"?""?",
		"?",

		"::=",
		":=",
		"::",
		":",

		"@",
		
		"...",
		".*",
		".",
		
		",",
		
		";",
		
		"==",
		//"=>",
		"=",

		"[",
		"]",
		"{",
		"}",
		"(",
		")",

		"<<<=",
		"<<<",
		"<<=",
		"<<",
		"<=",
		"<>",
		//"<-",
		"<",

		">>>=",
		">>>",
		">>=",
		">>",
		">=",
		">",

		"$",
		"##",
		"#"
	);

	specials_list_enums: TAGGED SpecialU[?](
		:AssignmentOp(:plusEqual),
		:PrefixOrPostfixOp(:doublePlus),
		:PrefixOrBinaryOp(:plus),

		:AssignmentOp(:minusEqual),
		:PrefixOp(:minusColon),
		:PrefixOrPostfixOp(:doubleMinus),
		:BinaryOp(:minusGreaterAsterisk),
		:BinaryOp(:minusGreater),
		:PrefixOrBinaryOp(:minus),

		:AssignmentOp(:asteriskEqual),
		:PrefixOrBinaryOp(:asterisk),

		:PrefixOp(:backslash),

		:AssignmentOp(:forwardSlashEqual),
		:BinaryOp(:forwardSlash),

		:AssignmentOp(:percentEqual),
		:BinaryOp(:percent),

		:BinaryOp(:exclamationMarkEqual),
		:PrefixOp(:exclamationMarkColon),
		:PrefixOp(:exclamationMark),

		:AssignmentOp(:circumflexEqual),
		:BinaryOp(:circumflex),

		:PrefixOp(:tildeColon),
		:PrefixOp(:tilde),

		:PrefixOp(:tripleAmp),
		:AssignmentOp(:doubleAmpEqual),
		:PrefixOrBinaryOp(:doubleAmp),
		:AssignmentOp(:ampEqual),
		:PrefixOrBinaryOp(:amp),

		:AssignmentOp(:doublePipeEqual),
		:BinaryOp(:doublePipe),
		:AssignmentOp(:pipeEqual),
		:BinaryOp(:pipe),

		:Punctuation(:doubleQuestionMark),
		:PostfixOp(:questionMark),

		:Punctuation(:doubleColonEqual),
		:AssignmentOp(:colonEqual),
		:Punctuation(:doubleColon),
		:Punctuation(:colon),

		:Punctuation(:at),
		
		:Punctuation(:tripleDot),
		:BinaryOp(:dotAsterisk),
		:BinaryOp(:dot),
		
		:Punctuation(:comma),
		
		:Punctuation(:semicolon),
		
		:BinaryOp(:doubleEqual),
		//:BinaryOp(:equalGreater),
		:FlowControlKw(:equal),

		:Punctuation(:bracketOpen),
		:Punctuation(:bracketClose),
		:Punctuation(:braceOpen),
		:Punctuation(:braceClose),
		:Punctuation(:parentheseOpen),
		:Punctuation(:parentheseClose),

		:AssignmentOp(:tripleLessEqual),
		:BinaryOp(:tripleLess),
		:AssignmentOp(:doubleLessEqual),
		:BinaryOp(:doubleLess),
		:BinaryOp(:lessEqual),
		:BinaryOp(:lessGreater),
		//:PrefixOp(:lessMinus),
		:BinaryOp(:less),

		:AssignmentOp(:tripleGreaterEqual),
		:BinaryOp(:tripleGreater),
		:AssignmentOp(:doubleGreaterEqual),
		:BinaryOp(:doubleGreater),
		:BinaryOp(:greaterEqual),
		:BinaryOp(:greater),

		:Punctuation(:dollar),
		:Punctuation(:doubleHash),
		:Punctuation(:hash)
	);

	specials_storage: {U4, U4, tok::Type, U1}[##specials_list_strings] (NOINIT);
	specials_lut: {U4, U4, tok::Type, U1}#[#][128] (NOINIT);

	init_specials_lut() VOID
	{
		specials_lut := (NULL);

		start: U1 := 0;
		startc: CHAR := specials_list_strings[0][0];

		FOR(##specials_list_strings)
		{
			storage: SpecialStorage := :Word(0);
			string ::= specials_list_strings[IOTA];
			FOR(i ::= 0; i < ##string; i++)
				storage.Chars[i] := string[i];

			specials_storage[IOTA].(0) := storage.Word;
			specials_storage[IOTA].(1) := <U4>(0xFFFFFFFF) >> (8 * ##string);
			specials_storage[IOTA].(2) := special_to_tok_type[specials_list_enums[IOTA].(0)];
			specials_storage[IOTA].(3) := <U1>(specials_list_enums[IOTA].(1).PrefixOp);

			IF(startc != string[0]) {
				specials_lut[startc] := specials_storage[FROM start UNTIL IOTA];
				start := IOTA;
				startc := string[0];
			}
		}
		specials_lut[startc] := specials_storage[FROM start];
	}
}