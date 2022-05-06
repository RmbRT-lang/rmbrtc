INCLUDE 'std/string'
INCLUDE 'std/io/file'
INCLUDE 'std/math/limit'

::rlc::src
{
	TYPE Index := U2;
	TYPE Size := U2;
	TYPE Line := U2;
	TYPE Column := U1;

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

		/// Returns a string encompassing this and the other string, and everything in between. 
		# span(other: String) String
		{
			start ::= std::math::min(Start, other.Start);
			end ::= std::math::max(Start+Length, other.Start+other.Length);

			RETURN (start, end-start);
		}

		# <BOOL> INLINE := Length != 0;
	}

	(// A line:column position inside a file. /)
	Position
	{
		Line: src::Line;
		Column: src::Column;
		File: src::File #\;
	}

	(// Source file. /)
	File
	{
		Name: std::Str;
		PUBLIC Contents: std::Str;

		{name: std::Str}: Name(:cstring(name!++))
		{
			f: std::io::File(Name.data(), "r");
			buf: CHAR[1024] (NOINIT);
			WHILE(!f.eof())
			{
				read ::= f.read(buf, ##buf);
				Contents.append(:buf(buf, read));
			}
		}

		# content(str: String #&) std::[CHAR#]Buffer
			:= Contents!.range((str.Start, str.Length));

		# position(
			index: Index,
			line: UINT \,
			column: UINT \) VOID
		{
			*line := 1;
			lineStart ::= 0;
			FOR(i ::= 0; i < index; i++)
				IF(Contents[i] == '\n')
				{
					++*line;
					lineStart := i;
				}
			*column := index - lineStart;
		}
	}
}