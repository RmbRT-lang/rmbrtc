::rlc::compiler CodeTokeniser
{
	TYPE Input := {tok::Tokeniser, tok::Token};
	TYPE Output := tok::FileTokens;	
	handle_job(
		input: {tok::Tokeniser, tok::Token} &,
		output: tok::FileTokens *
	) VOID
	{
		tokeniser ::= &&input.(0);
		first_token ::= input.(1);

		output->clear_reuse();
		output->reserve(512 * 1024);

		// Continue tokenising the files.
		DO(token ::= first_token)
		{
			*output += token;
		} WHILE(tokeniser.parse_next(&token))
		*output += <tok::Token>(:EOF);
	}
}