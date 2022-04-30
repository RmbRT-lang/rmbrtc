INCLUDE 'std/error'
INCLUDE 'std/string'
INCLUDE 'std/io/format'

::rlc::parser Error -> std::Error
{
	File: std::Utf8;
	Line: UINT;
	Column: UINT;
	Tokens: tok::Token[2];
	TokenContent: std::Utf8[2];
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
		File(file->Name),
		Line(line),
		Column(column),
		TokenCount(tokenCount),
		Context(p.context())
	{
		IF(tokenCount)
		{
			Tokens[0] := tokens[tokenIndex];
			TokenContent[0] := file->content(Tokens[0].Content);
		}
		IF(tokenCount == 2)
		{
			Tokens[1] := tokens[tokenIndex^1];
			TokenContent[1] := file->content(Tokens[1].Content);

		}
	}

	# ABSTRACT reason(std::io::OStream &) VOID;

	# FINAL stream(o: std::io::OStream &) VOID
	{
		o.write(File!, ':');
		std::io::format::dec(o, Line);
		o.write(":");
		std::io::format::dec(o, Column);
		o.write(": unexpected ");
		IF(TokenCount)
		{
			o.write(TokenContent[0]);
			IF(TokenCount > 1)
				o.write(:ch(' '), TokenContent[1]);
		} ELSE
			o.write("end of file");

		o.write(" in ", Context!, ": ");
		reason(o);
		o.write(:ch('.'));
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
		reason: std::str::C8CView#&
	} ->
		(file, line, column, tokens, tokenIndex, tokenCount, p):
		Reason(reason);

	# FINAL reason(o: std::io::OStream &) VOID
	{
		o.write(Reason!);
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
	} ->
		(file, line, column, tokens, tokenIndex, tokenCount, p):
		Expected(expected);

	# OVERRIDE reason(
		o: std::io::OStream &) VOID
	{
		o.write("expected ", <CHAR #\>(Expected));
	}
}