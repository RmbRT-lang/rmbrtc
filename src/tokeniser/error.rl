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
		o.write(File.content());
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
	Char: CHAR;
	{
		File: src::File #\,
		Line: UINT,
		Column: UINT,
		Char: CHAR}:
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
		Line: UINT,
		Column: UINT}:
		Error(File, Line, Column);

	# OVERRIDE reason(
		o: std::io::OStream &) VOID
	{
		o.write("unexpected end of file");
	}
}