INCLUDE "../src/file.rl"
INCLUDE 'std/error'
INCLUDE 'std/string'

::rlc::tok Error -> std::Error
{
	File: std::Utf8;
	Line: uint;
	Column: uint;

	CONSTRUCTOR(
		File: src::File #\,
		Line: uint,
		Column: uint):
		File(File->Name),
		Line(Line),
		Column(Column);

	PRIVATE STATIC itoa(i: int) char#\
	{
		STATIC buffer: char[32]("");
		libc::itoa::sprintf(buffer, "%d", i);
		RETURN buffer;
	}

	OVERRIDE print(
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
	CONSTRUCTOR(
		File: src::File #\,
		Line: uint,
		Column: uint,
		Char: char):
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
	CONSTRUCTOR(
		File: src::File #\,
		Line: uint,
		Column: uint):
		Error(File, Line, Column);

	# OVERRIDE reason(
		o: std::io::OStream &) VOID
	{
		o.write("unexpected end of file");
	}
}

::rlc::tok ExpectedToken -> Error
{
	Eof: bool;
	Actual: std::[char]Buffer;
	Expected: Type;

	CONSTRUCTOR(
		file: src::File #\,
		line: uint,
		column: uint,
		actual: Token #*,
		expected: Type):
		Error(file, line, column),
		Eof(actual == NULL),
		Expected(expected)
	{
		IF(!Eof)
			Actual := std::clone(file->content(actual->Content));
	}

	# OVERRIDE reason(
		o: std::io::OStream &) VOID
	{
		o.write("unexpected ");
		IF(Eof)
			o.write("end of file");
		ELSE
		{
			o.write("'");
			o.write(Actual);
			o.write("'");
		}
		o.write(": expected ");
		o.write(Expected.NAME());
	}
}


::libc::itoa EXTERN sprintf(char \, char #\, int) int;