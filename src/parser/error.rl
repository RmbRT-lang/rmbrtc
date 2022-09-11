INCLUDE 'std/error'
INCLUDE 'std/string'
INCLUDE 'std/io/format'
INCLUDE 'std/io/streamutil'

::rlc::parser Error -> std::Error
{
	File: std::Str;
	Line: UINT;
	Column: UINT;
	Tokens: tok::Token[2];
	TokenContent: std::Str[2];
	TokenCount: UINT;
	Context: std::Str;

	{
		file: src::File #\,
		line: UINT,
		column: UINT,
		tokens: tok::Token#\,
		tokenIndex: UINT,
		tokenCount: UINT,
		p: Parser#&}:
		File(file->Name),
		Line(line),
		Column(column),
		TokenCount(tokenCount),
		Context(p.context()),
		Tokens(NOINIT),
		TokenContent(NOINIT)
	{
		FOR(i ::= 0; i < ##Tokens; i++) Tokens[i].{BARE};
		FOR(i ::= 0; i < ##TokenContent; i++) TokenContent[i].{BARE};

		IF(tokenCount)
		{
			// TODO: bug prevents copy := operator to be used.
			Tokens[0].{tokens[tokenIndex]};
			TokenContent[0] := file->content(Tokens[0].Content)++;
		}
		IF(tokenCount == 2)
		{
			Tokens[1].{tokens[tokenIndex^1]};
			TokenContent[1] := file->content(Tokens[1].Content)++;
		}
	}

	# ABSTRACT reason(std::io::OStream &) VOID;

	# FINAL stream(o: std::io::OStream &) VOID
	{
		std::io::write(o,
			File!++, :ch(':'), :dec(Line), ":", :dec(Column), ": unexpected ");
		IF(TokenCount)
		{
			std::io::write(o, TokenContent[0]!++);
			IF(TokenCount > 1)
				std::io::write(o, :ch(' '), TokenContent[1]!++);
		} ELSE
			std::io::write(o, "end of file");

		std::io::write(o, " in ", Context!++, ": ");
		reason(o);
		std::io::write(o, :ch('.'));
	}
}

::rlc::parser ReasonError -> Error
{
	Reason: std::Str;

	{
		file: src::File #\,
		line: UINT,
		column: UINT,
		tokens: tok::Token#\,
		tokenIndex: UINT,
		tokenCount: UINT,
		p: Parser#&,
		reason: std::str::CV#&
	} ->
		(file, line, column, tokens, tokenIndex, tokenCount, p):
		Reason(reason);

	# FINAL reason(o: std::io::OStream &) VOID
	{
		std::io::write(o, Reason!++);
	}
}

::rlc::parser ExpectedToken -> Error
{
	Expected: tok::Type;

	{
		file: src::File #\,
		line: UINT,
		column: UINT,
		tokens: tok::Token#\,
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
		std::io::write(o, "expected ", <CHAR #\>(Expected));
	}
}