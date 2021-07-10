INCLUDE 'std/error'
INCLUDE 'std/string'
INCLUDE 'std/io/format'

::rlc::parser Error -> std::Error
{
	File: std::Utf8;
	Line: UINT;
	Column: UINT;
	Tokens: tok::Token[2];
	TokenContent: std::[CHAR]Buffer[2];
	TokenCount: UINT;
	Context: std::Utf8;

	{
		file: src::File #\,
		line: UINT,
		column: UINT,
		tokens: tok::Token#[2]&,
		tokenIndex: UINT,
		tokenCount: UINT,
		p: Parser#&}:
		File(std::Utf8(file->Name)),
		Line(line),
		Column(column),
		TokenCount(tokenCount),
		Context(p.context())
	{
		IF(tokenCount)
		{
			Tokens[0] := tokens[tokenIndex];
			TokenContent[0] := std::clone(file->content(Tokens[0].Content));
		}
		IF(tokenCount == 2)
		{
			Tokens[1] := tokens[tokenIndex^1];
			TokenContent[1] := std::clone(file->content(Tokens[1].Content));

		}
	}

	# ABSTRACT reason(std::io::OStream &) VOID;

	# FINAL print(o: std::io::OStream &) VOID
	{
		o.write(File.content());
		o.write(":");
		std::io::format::dec(o, Line);
		o.write(":");
		std::io::format::dec(o, Column);
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
		reason(o);
		o.write(".\n");
	}
}

::rlc::parser ReasonError -> Error
{
	Reason: std::Utf8;

	{
		file: src::File #\,
		line: UINT,
		column: UINT,
		tokens: tok::Token#[2]&,
		tokenIndex: UINT,
		tokenCount: UINT,
		p: Parser#&,
		reason: CHAR #\
	}->	Error(file, line, column, tokens, tokenIndex, tokenCount, p)
	:	Reason(reason, :cstring);

	# FINAL reason(o: std::io::OStream &) VOID
	{
		o.write(Reason.content());
	}
}
::rlc::parser ExpectedToken -> Error
{
	Expected: tok::Type;

	{
		file: src::File #\,
		line: UINT,
		column: UINT,
		tokens: tok::Token#[2]&,
		tokenIndex: UINT,
		tokenCount: UINT,
		p: Parser#&,
		expected: tok::Type
	}->	Error(file, line, column, tokens, tokenIndex, tokenCount, p)
	:	Expected(expected);

	# OVERRIDE reason(
		o: std::io::OStream &) VOID
	{
		o.write("expected ");
		o.write(Expected.NAME());
	}
}
