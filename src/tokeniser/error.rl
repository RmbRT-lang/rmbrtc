INCLUDE "../src/file.rl"
INCLUDE 'std/error'
INCLUDE 'std/string'

::rlc::tok Error -> std::Error
{
	File: std::Str;
	Line: UINT;
	Column: UINT;

	{
		File: src::File #\,
		Line: UINT,
		Column: UINT}:
		File(File->Name),
		Line(Line),
		Column(Column);

	# OVERRIDE stream(
		o: std::io::OStream &) VOID
	{
		std::io::write(o, File!++, ":", :dec(Line), ":", :dec(Column), ": ");

		reason(o);
		std::io::write(o, ".");
	}

	# ABSTRACT reason(
		std::io::OStream &) VOID;
}

::rlc::tok UnexpectedChar -> Error
{
	Char: U4;
	{
		File: src::File #\,
		Line: UINT,
		Column: UINT,
		Char: U4
	} -> (File, Line, Column)
	:	Char(Char);

	# OVERRIDE reason(
		o: std::io::OStream &) VOID
	{
		std::io::write(o, "unexpected character '");
		SWITCH(Char)
		{
		'\t': std::io::write(o, "\\t");
		'\n': std::io::write(o, "\\n");
		DEFAULT:
			{
				u8: CHAR[4] (NOINIT);
				len ::= std::code::utf8::encode(Char, u8!);
				std::io::write(o, :buf(u8!, len));
			}
		}
		std::io::write(o, "'");
	}
}

::rlc::tok UnexpectedEOF -> Error
{
	{
		file: src::File #\,
		line: UINT,
		column: UINT
	} -> (file, line, column);

	# OVERRIDE reason(
		o: std::io::OStream &) VOID
	{
		std::io::write(o, "unexpected end of file");
	}
}

::rlc::tok InvalidCharSeq -> Error
{
	{
		file: src::File #\,
		line: UINT,
		column: UINT
	} -> (file, line, column);

	# OVERRIDE reason(
		o: std::io::OStream &) VOID
	{
		std::io::write(o, "invalid character sequence");
	}
}