INCLUDE 'std/error'
INCLUDE 'std/string'

::rlc::parser Error -> std::Error
{
	File: std::Utf8;
	Line: uint;
	Column: uint;
	Tokens: tok::Token[2];
	TokenContent: std::[char]Buffer[2];
	TokenCount: uint;
	Context: std::Utf8;
	Reason: char #\;

	CONSTRUCTOR(
		file: src::File #\,
		line: uint,
		column: uint,
		tokens: tok::Token#[2]&,
		tokenIndex: uint,
		tokenCount: uint,
		p: Parser#&,
		reason: char#\):
		File(std::Utf8(file->Name)),
		Line(line),
		Column(column),
		TokenCount(tokenCount),
		Context(p.context()),
		Reason(reason)
	{
		IF(tokenCount)
		{
			Tokens[0] := tokens[tokenIndex];
			TokenContent[0] := std::clone(file->content(tokens[0].Content));
		}
		IF(tokenCount == 2)
		{
			Tokens[1] := tokens[tokenIndex^1];
			TokenContent[1] := std::clone(file->content(tokens[1].Content));

		}
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
			o.write(TokenContent[0]);
			IF(TokenCount > 1)
			{
				o.write(" ");
				o.write(TokenContent[1]);
			}
		} ELSE
			o.write("end of file");

		o.write(" in ");
		o.write(Context.content());
		o.write(": ");
		o.write(Reason);
		o.write(".\n");
	}
}

::libc::itoa EXTERN sprintf(char \, char #\, int) int;
