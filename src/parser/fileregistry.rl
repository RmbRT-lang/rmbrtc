INCLUDE "detail/global.rl"
INCLUDE "detail/member.rl"
INCLUDE "file.rl"

INCLUDE 'std/string'
INCLUDE 'std/set'

::rlc::parser FileRegistry
{
PRIVATE:
	Utf8Cmp
	{
		STATIC cmp(
			a: std::Utf8 #&,
			b: File # \
		) INLINE INT
			:= a.cmp(b->name());
	}

	Files: std::[File - std::Dynamic, Utf8Cmp]VectorSet;
	FileByNumber: parser::File #\-std::Vector;

PUBLIC:
	get(file: std::Utf8 #&) File \
	{
		loc: std::[std::[File]Dynamic, Utf8Cmp]VectorSet::Location;
		IF(entry ::= Files.find(file, &loc))
			RETURN *entry;
		ELSE
		{
			max_files: UM# := ~<src::FileNo>(0);
			ASSERT(##Files < max_files);
			f ::= Files.emplace_at(loc, :gc(std::[File]new(file, ##Files)))!;
			FileByNumber += f;
			RETURN f;
		}
	}

	# nameByNumber(n: src::FileNo) CHAR#-std::Buffer
		:= FileByNumber[n]->Src.Name!;
	# positionByFileNumber(i: src::Index, n: src::FileNo) src::Position
	{
		pos: {UINT, UINT};
		FileByNumber[n]->Src.position(i, &pos.(0), &pos.(1));
		RETURN (n, pos.(0), pos.(1));
	}
}