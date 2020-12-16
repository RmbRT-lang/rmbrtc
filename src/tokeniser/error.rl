INCLUDE "../src/file.rl"
INCLUDE 'std/error'
INCLUDE 'std/string'

::rlc::tok Error -> std::Error
{
	File: std::Utf8;
	Line: uint;
	Column: uint;

	{
		File: src::File #\,
		Line: uint,
		Column: uint}:
		File(File->Name),
		Line(Line),
		Column(Column);

	PRIVATE STATIC itoa(i: int) char#\
	{
		STATIC buffer: char[32]("");
		libc::itoa::sprintf(buffer, "%d", i);
		RETURN buffer;
	}

	# OVERRIDE print(
		o: std::io::OStream &) VOID
	{
		o.write(File.content());
		o.write(":");
		o.write(itoa(Line));
		o.write(":");
		o.write(itoa(Column));
		o.write(": ");

		reason(o);
		o.write(".");
	}

	# ABSTRACT reason(
		std::io::OStream &) VOID;
}

::rlc::tok UnexpectedChar -> Error
{
	Char: char;
	{
		File: src::File #\,
		Line: uint,
		Column: uint,
		Char: char}:
		Error(File, Line, Column),
		Char(Char);

	# OVERRIDE reason(
		o: std::io::OStream &) VOID
	{
		o.write("unexpected character '");
		SWITCH(Char)
		{
		CASE '\t': { o.write("\\t"); BREAK; }
		CASE '\n': { o.write("\\n"); BREAK; }
		DEFAULT:
			o.write(&Char, 1);
		}
		o.write("'");
	}
}

::rlc::tok UnexpectedEOF -> Error
{
	{
		File: src::File #\,
		Line: uint,
		Column: uint}:
		Error(File, Line, Column);

	# OVERRIDE reason(
		o: std::io::OStream &) VOID
	{
		o.write("unexpected end of file");
	}
}

::libc::itoa EXTERN sprintf(char \, char #\, int) int;