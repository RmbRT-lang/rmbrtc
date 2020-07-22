INCLUDE 'std/string'
INCLUDE 'std/io/file'

::rlc::src
{
	TYPE Index := uint16_t;
	TYPE Size := uint16_t;

	(// String inside a source file. /)
	String
	{
		CONSTRUCTOR();
		CONSTRUCTOR(start: Index, length: Size):
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

		CONSTRUCTOR(name: std::Utf8): Name(name)
		{
			f: std::io::File(Name.data(), "r");
			buf: char[1024];
			WHILE(!f.eof())
			{
				read ::= f.read(buf, SIZEOF(#buf));
				Contents.append(buf, read);
			}
		}

		# content(str: String #&) std::[char#]Buffer
			:= Contents.substring(str.Start, str.Length);

		# position(
			index: Index,
			line: uint \,
			column: uint \) VOID
		{
			*line := 1;
			lineStart ::= 0;
			content ::= Contents.content();
			FOR(i ::= 0; i < index; i++)
				IF(content.at(i) == '\n')
				{
					++*line;
					lineStart := i;
				}
			*column := index - lineStart;
		}
	}
}