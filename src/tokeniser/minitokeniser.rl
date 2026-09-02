::rlc::tok
{
	MiniTokeniser
	{
		Content: CHAR # *;

		# get_8() U8 -- := *<U8# *>(Content);
		# get_2() U8 -- := *<U2# *>(Content);

		UNION MiniToken {
			none;
			include;
		?	stringApostrophe: CHAR #[#];
		?	stringQuote: CHAR #[#];
		}
		get_token() TAGGED MiniToken
		{
			FOR(;;) SWITCH(*Content)
			{
			'I': {
				IF(get_8() & 0rffffffffffffff00 == 0r494e434c55444500)
				{
					Content += 7;
					RETURN :include;
				} ELSE RETURN :none;
				}
			' ', '\t', '\n': { ++Content; }
			'(': {
				IF(get_2() == 0r282f) {
					Content += 2;
					nesting ::= 1;
					DO()
					{
						x ::= get_2();
						enter ::= x == 0r282f;
						leave ::= x == 0r2f29;

						nesting += enter - leave;
						Content += 1 + (enter | leave);
					} WHILE(nesting)
				} ELSE = :none;
			}
			'/': {
				IF(get_2() == 0r2f2f)
				{
					Content += 2;
					WHILE(*Content++ != '\n') {;}
				} ELSE = :none;
			}
			'\'': {
				start ::= Content++;
				WHILE(*Content++ != '\'') {;}

				= :stringApostrophe(start[FOR (Content-start)]);
			}
			'"': {
				start ::= Content++;
				WHILE(*Content++ != '"') {;}

				= :stringQuote(start[FOR (Content-start)]);
			}
			DEFAULT: = :none;
			}
		}
	}
}