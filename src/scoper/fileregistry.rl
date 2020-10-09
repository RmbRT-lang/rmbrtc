INCLUDE "file.rl"
INCLUDE "../util/file.rl"
INCLUDE "../parser/fileregistry.rl"

INCLUDE "detail/global.rl"
INCLUDE "detail/member.rl"
INCLUDE "detail/expression.rl"
INCLUDE "detail/statement.rl"

INCLUDE 'std/memory'
INCLUDE 'std/set'


::rlc::scoper FileRegistry
{
	ParsedFiles: parser::FileRegistry;
	Loading: std::[std::[char#]Buffer, FileRegistry]VectorSet;
	Files: std::[std::[File]Dynamic, FileRegistry]VectorSet;
	IncludeDirs: std::[std::Utf8]Vector;


	CONSTRUCTOR()
	{
		load_include_dirs();
	}

	(// Returns pointer to file, or null if the file is currently being loaded. /)
	get(path: std::[char#]Buffer #&) File *
	{
		loc: std::[std::[File]Dynamic, FileRegistry]VectorSet::Location;
		IF(f ::= Files.find(path, &loc))
			RETURN *f;

		IF(!Loading.insert(path))
			RETURN NULL;
		f ::= Files.emplace_at(loc, ::[File]new(*ParsedFiles.get(path), *THIS)).Ptr;
		IF(!Loading.remove(path))
			THROW;
		RETURN f;
	}

	find_global(path: std::[char#]Buffer #&) std::Utf8
	{
		FOR(i ::= 0; i < IncludeDirs.size(); i++)
			TRY RETURN util::absolute_file(
				util::concat_paths(
					IncludeDirs[i].content(),
					path).content());
			CATCH() { ; }

		THROW;
	}

	STATIC cmp(
		key: std::[char#]Buffer #&,
		entry: File #\) INLINE
		::= -entry->Source->Name.cmp(key);
	STATIC cmp(
		key: std::[char#]Buffer #&,
		entry: std::[char#]Buffer #&) INLINE
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
				IncludeDirs.emplace_back(incs.cut(len));
		} FOR(incs.Size > len; incs := incs.drop_start(len+1))
	}
}

::rlc::scoper::detail EXTERN getenv(char #*) char # *;