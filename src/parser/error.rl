INCLUDE 'std/error'
INCLUDE 'std/string'

::rlc::parser Error -> std::Error
{
	File: std::Utf8;
	Line: uint;
	Column: uint;
	Tokens: tok::Token[2];
	TokenCount: uint;
	Context: std::Utf8;

	CONSTRUCTOR(
		file: std::Utf8&&,
		line: uint,
		column: uint,
		tokens: tok::Token#[2]&,
		tokenIndex: uint,
		tokenCount: uint,
		p: Parser#&):
		File(__cpp_std::move(file)),
		Line(line),
		Column(column),
		TokenCount(tokenCount)
	{
		IF(tokenCount)
			Tokens[0] := tokens[tokenIndex];
		IF(tokenCount == 2)
			Tokens[1] := tokens[tokenIndex^1];
	}

	PRIVATE STATIC itoa(i: int) char#\
	{
		STATIC buffer: char[32]("");
		libc::itoa::sprintf(buffer, "%d", i);
		RETURN buffer;
	}

	FINAL print(o: std::io::OStream &) VOID
	{
		o.write(File.content());
		o.write(":");
		o.write(itoa(Line));
		o.write(":");
		o.write(itoa(Column));
		o.write(": unexpected ");
		IF(TokenCount)
		{
			o.write(Tokens[0].Type.NAME());
		}
		IF(TokenCount > 1)
		{
			o.write(" ");
			o.write(Tokens[1].Type.NAME());
		}
		IF(!TokenCount)
			o.write("end of file");

		o.write(" in ");

	}
}

::libc::itoa EXTERN sprintf(char \, char #\, int) int;
