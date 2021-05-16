INCLUDE "scope.rl"
INCLUDE "fileregistry.rl"
INCLUDE "types.rl"
INCLUDE "string.rl"

INCLUDE "../parser/file.rl"
INCLUDE "../util/file.rl"

INCLUDE 'std/set'
INCLUDE 'std/string'
INCLUDE 'std/shared'

::rlc::scoper File
{
	Scope: scoper::Scope - std::Shared;
	Source: src::File #\;

	Includes: std::[File \, File]VectorSet;
	IncludedBy: std::[File \, File]VectorSet;

	(// Creates a file with an empty scope. /)
	{
		parsed: parser::File #&,
		registry: FileRegistry &
	}:	File(:create(NULL, NULL), parsed, registry);

	(//
	Creates a file with a custom scope, which may or may not be used by other files already. This is used especially for unified legacy scoping.
	/)
	{
		scope: scoper::Scope - std::Shared,
		parsed: parser::File #&,
		registry: FileRegistry &
	}:	Scope(scope),
		Source(&parsed.Src)
	{
		FOR(i ::= 0; i < parsed.RootScope.size(); i++)
			Scope->insert(parsed.RootScope[i], *Source);

		// Resolve and load all include files.
		loc: std::[File \, File]VectorSet::Location;
		path: std::Utf8;
		FOR(i ::= 0; i < parsed.Includes.size(); i++)
		{
			path := Text(parsed.Includes[i].Token, *Source).utf8();
			TRY SWITCH(type ::= parsed.Includes[i].Type)
			{
			CASE :relative: path := relative_path(path.content());
			CASE :global: path := registry.find_global(path.content());
			DEFAULT:
				THROW <std::err::Unimplemented>(type.NAME());
			}
			CATCH(std::io::FileNotFound&)
				THROW <IncludeNotFound>(THIS, &&path, parsed.Includes[i].Type);

			IF(!Includes.find(path, &loc))
			{
				IF(file ::= registry.get(path.content()))
				{
					Includes.emplace_at(loc, file);
					file->IncludedBy.insert(file);
					IncludedBy.insert(file);
					file->Includes.insert(&THIS);
				}
			}
		}
	}

	IncludeNotFound -> std::Error
	{
		Source: std::Utf8;
		Include: std::Utf8;
		Type: IncludeType;

		{
			source: File #&,
			path: std::Utf8&&,
			type: IncludeType
		}:	Source(source.Source->Name),
			Include(&&path),
			Type(type);


		# FINAL print(o: std::io::OStream &) VOID
		{
			o.write_all(Source.content(), ": ", Type.NAME(), " include '", Include.content(), "' not found");
		}
	}

	# relative_path(relative: String#&) std::Utf8
		:= util::absolute_file(
			util::concat_paths(
				util::parent_dir(Source->Name.content()),
				relative).content());

	STATIC cmp(a: std::Utf8 #&, b: File \) INLINE
		::= a.cmp(b->Source->Name);
	STATIC cmp(a: std::[char#]Buffer #&, b: File \) INLINE
		::= std::str::cmp(a, b->Source->Name.content());
	STATIC cmp(a: File \, b: File \) INLINE
		::= a->Source->Name.cmp(b->Source->Name);
}