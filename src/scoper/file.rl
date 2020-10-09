INCLUDE "scope.rl"
INCLUDE "fileregistry.rl"
INCLUDE "types.rl"
INCLUDE "string.rl"

INCLUDE "../parser/file.rl"
INCLUDE "../util/file.rl"

INCLUDE 'std/set'
INCLUDE 'std/string'

::rlc::scoper File
{
	Scope: scoper::Scope;
	Source: src::File #\;

	Includes: std::[File \, File]VectorSet;
	IncludedBy: std::[File \, File]VectorSet;

	CONSTRUCTOR(
		parsed: parser::File #&,
		registry: FileRegistry &):
		Scope(NULL, NULL),
		Source(&parsed.Src)
	{
		FOR(i ::= 0; i < parsed.RootScope.size(); i++)
			Scope.insert(parsed.RootScope[i], *Source);

		// Resolve and load all include files.
		loc: std::[File \, File]VectorSet::Location;
		path: std::Utf8;
		FOR(i ::= 0; i < parsed.Includes.size(); i++)
		{
			path := Text(parsed.Includes[i].Token, *Source).utf8();
			IF(parsed.Includes[i].Type == rlc::IncludeType::relative)
				path := relative_path(path.content());
			ELSE IF(parsed.Includes[i].Type == rlc::IncludeType::global)
				path := registry.find_global(path.content());
			ELSE
				THROW;

			IF(!Includes.find(path, &loc))
			{
				IF(file ::= registry.get(path.content()))
				{
					Includes.emplace_at(loc, file);
					file->IncludedBy.insert(file);
					IncludedBy.insert(file);
					file->Includes.insert(THIS);
				}
			}
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