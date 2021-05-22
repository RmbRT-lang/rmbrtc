INCLUDE 'std/string'
INCLUDE 'std/io/file'

::rlc::src
{
	TYPE Index := uint16_t;
	TYPE Size := uint16_t;

	(// String inside a source file. /)
	String
	{
		{};
		{start: Index, length: Size}:
			Start(start),
			Length(length);

		STATIC empty: String#(0,0);

		Start: Index;
		Length: Size;

		# exists() INLINE ::= Length != 0;
	}

	(// Source file. /)
	File
	{
		Name: std::Utf8;
		PUBLIC Contents: std::Utf8;

		{name: std::Utf8}: Name(name, :cstring)
		{
			f: std::io::File(Name.data(), "r");
			buf: CHAR[1024];
			WHILE(!f.eof())
			{
				read ::= f.read(buf, SIZEOF(#buf));
				Contents.append(buf, read);
			}
		}

		# content(str: String #&) std::[CHAR#]Buffer
			:= Contents.substring(str.Start, str.Length);

		# position(
			index: Index,
			line: UINT \,
			column: UINT \) VOID
		{
			*line := 1;
			lineStart ::= 0;
			content ::= Contents.content();
			FOR(i ::= 0; i < index; i++)
				IF(content[i] == '\n')
				{
					++*line;
					lineStart := i;
				}
			*column := index - lineStart;
		}
	}
}