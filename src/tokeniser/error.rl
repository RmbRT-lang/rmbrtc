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

	os::term::PrintLine_v(:style(:normal, :red),
		std::str::c(w.(0)[]), ":",
		std::io::format::dec(w.(1)), ":",
		std::io::format::dec(w.(2)), ": error: "
		"unexpected character '", char, "'");
	os::terminate_error();
}

::rlc::tok::err unexpected_eof(w: WHERE) VOID
{
	os::term::PrintLine_v(:style(:normal, :red),
		std::str::c(w.(0)[]), ":",
		std::io::format::dec(w.(1)), ":",
		std::io::format::dec(w.(2)), ": error: "
		"unexpected end of file");
	os::terminate_error();
}

::rlc::tok::err invalid_char_seq(w: WHERE) VOID
{
	os::term::PrintLine_v(:style(:normal, :red),
		std::str::c(w.(0)[]), ":",
		std::io::format::dec(w.(1)), ":",
		std::io::format::dec(w.(2)), ": error: "
		"invalid character sequence");
	os::terminate_error();
}


::rlc::tok::err msg(w: WHERE, msg: CHAR#[#]) VOID
{
	os::term::PrintLine_v(:style(:normal, :red),
		std::str::c(w.(0)[]), ":",
		std::io::format::dec(w.(1)), ":",
		std::io::format::dec(w.(2)), ": error: ",
		msg);
	os::terminate_error();
}
