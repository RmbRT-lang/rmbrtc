INCLUDE "../src/file.rl"
INCLUDE 'std/error'
INCLUDE 'std/string'

::rlc::tok Error -> std::Error
{
	File: std::Utf8;
	Line: UINT;
	Column: UINT;

	{
		File: src::File #\,
		Line: UINT,
		Column: UINT}:
		File(File->Name),
		Line(Line),
		Column(Column);

	# OVERRIDE print(
		o: std::io::OStream &) VOID
	{
		o.write(File!);
		o.write(":");
		std::io::format::dec(o, Line);
		o.write(":");
		std::io::format::dec(o, Column);
		o.write(": ");

		reason(o);
		o.write(".");
	}

	# ABSTRACT reason(
		std::io::OStream &) VOID;
}

::rlc::tok UnexpectedChar -> Error
{
	Char: std::SYM;
	{
		File: src::File #\,
		Line: UINT,
		Column: UINT,
		Char: std::SYM
	}->	Error(File, Line, Column)
	:	Char(Char);

	# OVERRIDE reason(
		o: std::io::OStream &) VOID
	{
		o.write("unexpected character '");
		SWITCH(Char)
		{
		'\t': o.write("\\t");
		'\n': o.write("\\n");
		DEFAULT:
			{
				u8: CHAR[4];
				len ::= std::code::utf8::encode(Char, u8);
				o.write(&u8, len);
			}
		}
		o.write("'");
	}
}

::rlc::tok UnexpectedEOF -> Error
{
	{
		file: src::File #\,
		line: UINT,
		column: UINT
	}->	Error(file, line, column);

	# OVERRIDE reason(
		o: std::io::OStream &) VOID
	{
		o.write("unexpected end of file");
	}
}

::rlc::tok InvalidCharSeq -> Error
{
	{
		file: src::File #\,
		line: UINT,
		column: UINT
	}->	Error(file, line, column);

	# OVERRIDE reason(
		o: std::io::OStream &) VOID
	{
		o.write("invalid character sequence");
	}
}