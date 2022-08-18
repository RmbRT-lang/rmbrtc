INCLUDE 'std/string'
INCLUDE 'std/set'
INCLUDE 'std/hashmap'

INCLUDE "../compiler/compiler.rl"
INCLUDE "file.rl"

::rlc::ast [Stage:TYPE] FileRegistry
{
PRIVATE:
	Files: [Stage]File-std::DynVec;
	FileByName: std::[std::str::CV, [Stage]File\]AutoMap;

	Context: Stage \;
PUBLIC:
	{ctx: Stage \}: Context(ctx);

	get(file: std::Str #&) Stage-File \
	{
		entry ::= FileByName.find_loc(file!);
		IF(f ::= entry.(0))
			= (*f)!;
		ELSE
		{
			processed ::= Context->create_file(file!);
			FileByName.insert_at(entry.(1), processed->Name!, processed!);
			= (Files += &&processed)!;
		}
	}
}