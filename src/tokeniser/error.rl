INCLUDE "../src/file.rl"
INCLUDE 'os/terminal'
INCLUDE 'os/runtime'
INCLUDE 'std/str'
INCLUDE 'std/unicode'

::rlc::tok::err unexpected_char(w: WHERE, c: U4) VOID
{
	char_enc: CHAR[4] (NOINIT);
	char: CHAR#[#] (NOINIT);

	SWITCH(c)
	{
	'\t': char := "\\t";
	'\n': char := "\\n";
	DEFAULT:
	{
		len ::= std::code::utf8::encode(c, char_enc[]);
		char := char_enc[FOR len];
	}
	}

	term::error(w, "unexpected character '", char, "'");
}

::rlc::tok::err unexpected_eof(w: WHERE) VOID
{
	term::error(w, "unexpected end of file");
}

::rlc::tok::err invalid_char_seq(w: WHERE) VOID
{
	term::error(w, "invalid character sequence");
}


::rlc::tok::err [Msg...]msg(w: WHERE, msg: Msg!&&...) VOID
{
	term::error(w, <Msg!&&>(msg)...);
}
