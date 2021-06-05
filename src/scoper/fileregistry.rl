INCLUDE "file.rl"
INCLUDE "../util/file.rl"
INCLUDE "../parser/fileregistry.rl"

INCLUDE "detail/global.rl"
INCLUDE "detail/member.rl"
INCLUDE "detail/expression.rl"
INCLUDE "detail/statement.rl"
INCLUDE "detail/type.rl"

INCLUDE 'std/memory'
INCLUDE 'std/set'
INCLUDE 'std/shared'


::rlc::scoper FileRegistry
{
	ParsedFiles: parser::FileRegistry;
	Loading: std::[std::[CHAR#]Buffer, FileRegistry]VectorSet;
	Files: std::[std::[File]Dynamic, FileRegistry]VectorSet;
	IncludeDirs: std::[std::Utf8]Vector;
	(// Set this to create one global scope for all files. /)
	LegacyScope: Scope - std::Shared;

	{}
	{
		load_include_dirs();
	}

	(// Returns pointer to file, or null if the file is currently being loaded. /)
	get(path: std::[CHAR#]Buffer #&) File *
	{
		loc: std::[std::[File]Dynamic, FileRegistry]VectorSet::Location;
		IF(f ::= Files.find(path))
			RETURN *f;

		IF(!Loading.insert(path))
			RETURN NULL;
		file: File \ := LegacyScope
			? std::[File]new(LegacyScope, *ParsedFiles.get(path), THIS)
			: std::[File]new(*ParsedFiles.get(path), THIS);

		ASSERT(Files.insert(:gc(file)));
		ASSERT(Loading.remove(path));
		RETURN file;
	}

	find_global(path: std::[CHAR#]Buffer #&) std::Utf8
	{
		FOR(i ::= 0; i < ##IncludeDirs; i++)
			TRY RETURN util::absolute_file(
				util::concat_paths(
					IncludeDirs[i].content(),
					path).content());
			CATCH() { ; }

		THROW;
	}


	STATIC cmp(
		key: File #\,
		entry: File #\) INLINE
		::= key->Source->Name.cmp(entry->Source->Name);
	STATIC cmp(
		key: std::[CHAR#]Buffer #&,
		entry: File #\) INLINE
		::= std::str::cmp(key, entry->Source->Name.content());
	STATIC cmp(
		key: std::[CHAR#]Buffer #&,
		entry: std::[CHAR#]Buffer #&) INLINE
		::= std::str::cmp(key, entry);

	PRIVATE load_include_dirs() VOID
	{
		incs ::= std::str::buf(detail::getenv("RLINCLUDE"));
		DO(len: UM)
		{
			FOR(len := 0; len < incs.Size; len++)
				IF(incs[len] == ':')
					BREAK;

			IF(len)
				IncludeDirs += incs.cut(len);
		} FOR(incs.Size > len; incs := incs.drop_start(len+1))
	}
}

::rlc::scoper::detail EXTERN getenv(CHAR #*) CHAR # *;