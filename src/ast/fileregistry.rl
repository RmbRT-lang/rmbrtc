INCLUDE 'std/string'
INCLUDE 'std/set'
INCLUDE 'std/hashmap'

INCLUDE "../compiler/compiler.rl"
INCLUDE "file.rl"

::rlc::ast [Stage:TYPE] FileRegistry
{
PRIVATE:
	Files: [Stage]File-std::DynVec;
	FileByName: std::[std::str::CV, [Stage]File\]Map;
	Loading: std::[std::str::CV]VecSet;

	Context: Stage \;
PUBLIC:
	{ctx: Stage \}: Context(ctx);

	# start() ? := Files.start();

	# ## THIS UM := ##Files;

	get(file: std::Str #&) Stage-File \
	{
		entry ::= FileByName.find_loc(file!);
		IF(f ::= entry.(0))
			= *f;
		ELSE
		{
			IF(Loading.has(file!))
				THROW :loading;
			Loading += file!;
			processed ::= Context->create_file(file!);
			FileByName.insert(processed->Source->Name!, &processed!);
			Loading -= file!;
			= (Files += &&processed);
		}
	}
}