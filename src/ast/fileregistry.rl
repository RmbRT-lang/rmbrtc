INCLUDE 'std/string'
INCLUDE 'std/set'
INCLUDE 'std/hashmap'

INCLUDE "../compiler/compiler.rl"
INCLUDE "file.rl"

::rlc::ast [Stage:TYPE] FileRegistry
{
PRIVATE:
	StrCmp
	{
		STATIC cmp(lhs: std::Str#&, rhs: std::Str#&) ? := lhs!.cmp(rhs!);
	}

	Files: [Stage]File-std::DynVec;
	FileByName: std::[std::Str, [Stage]File\, StrCmp]Map;

	Context: Stage \;
PUBLIC:
	{ctx: Stage \}: Context(ctx);

	get(file: std::Str #&) Stage-File \
	{
		entry ::= FileByName.find_loc(file);
		IF(f ::= entry.(0))
			= (*f)!;
		ELSE
		{
			processed ::= Context->create_file(file!);
			FileByName.insert_at(entry.(1), file, processed);
			Files += :gc(processed);
			= processed;
		}
	}
}