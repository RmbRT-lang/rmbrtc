INCLUDE 'std/string'
INCLUDE 'std/set'
INCLUDE 'std/hashmap'
INCLUDE 'std/sync/mutex'

INCLUDE "../compiler/compiler.rl"
INCLUDE "file.rl"

::rlc::ast [Stage:TYPE] FileRegistry -> PRIVATE std::sync::Mutex
{
PRIVATE:
	StrCmp
	{
		STATIC cmp(
			a: std::Str #&,
			b: Stage-File # \
		) INT INLINE
			:= a!.cmp(b->name());
	}

	Files: Stage-File-std::DynVec;
	FileFutures: Stage-File\^-std::DynVec;
	FileByName: std::[std::Str, Stage-File\^\]HashMap;
	FileByNumber: Stage-File^\-std::Vec;
PUBLIC:
	get(file: std::Str #&) Stage-File \
	{
		STATIC max_files: UM# := ~<src::FileNo>(0);

		g ::= THIS();
		entry ::= FileByName.find_loc(file);
		IF(f ::= entry.(0))
		{
			g.~;
			RETURN (**f)();
		} ELSE
		{
			loc ::= entry.(1);

			ASSERT(##Files < max_files);
			fH ::= (FileFutures += :new(^std::heap::[[Stage]File]new(file, ##Files)))!;
			FileByNumber += FileByName.insert(file, fH);
			g.~;
			file ::= (*fH)();
			g := THIS();
			Files += :gc(file);
			= file;
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