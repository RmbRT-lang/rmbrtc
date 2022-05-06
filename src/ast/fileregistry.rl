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
PUBLIC:
	get(file: std::Str #&) Stage-File \
	{
		g ::= THIS();
		entry ::= FileByName.find_loc(file);
		IF(f ::= entry.(0))
		{
			g.~;
			RETURN (**f)();
		} ELSE
		{
			loc ::= entry.(1);

			fH ::= (FileFutures += :dup(^Stage::create_file(THIS, file!)))!;
			FileByName.insert(file, fH);
			g.~;
			file ::= (*fH)();
			g := THIS();
			Files += :gc(file);
			= file;
		}
	}
}