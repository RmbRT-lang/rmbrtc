INCLUDE "scope.rl"
INCLUDE "fileregistry.rl"
INCLUDE "types.rl"
INCLUDE "string.rl"
INCLUDE "error.rl"

INCLUDE "../parser/file.rl"
INCLUDE "../util/file.rl"

INCLUDE 'std/set'
INCLUDE 'std/string'
INCLUDE 'std/shared'

::rlc::scoper File
{
	Scope: scoper::Scope - std::Shared;
	Source: src::File #\;

	Includes: std::[File \; File]VectorSet;
	IncludedBy: std::[File \; File]VectorSet;

	# name() #& ::= Source->Name;

	(// Creates a file with an empty scope. /)
	{
		parsed: parser::File #&,
		registry: FileRegistry &
	}->	File(:create(NULL, NULL), parsed, registry);

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
		FOR(i ::= 0; i < ##parsed.RootScope; i++)
			Scope->insert(<<parser::ScopeItem #\>>(parsed.RootScope[i]), parsed);

		// Resolve and load all include files.
		loc: std::[File \; File]VectorSet::Location;
		path: std::Utf8;
		FOR(inc ::= parsed.Includes.start(); inc; ++inc)
		{
			path := Text(inc->Token, *Source).utf8();
			TRY SWITCH(type ::= inc!.Type)
			{
			:relative: path := relative_path(path!);
			:global: path := registry.find_global(path!);
			DEFAULT:
				THROW <std::err::Unimplemented>(type.NAME());
			}
			CATCH(std::io::FileNotFound&)
				THROW <IncludeNotFound>(inc!.Token.Position, &&path, inc!.Type);

			IF(!Includes.find(path, &loc))
			{
				IF(file ::= registry.get(path!))
				{
					Includes += (:at(loc), file);
					file->IncludedBy += file;
					IncludedBy += file;
					file->Includes += &THIS;
				}
			}
		}
	}

	IncludeNotFound -> Error
	{
		Include: std::Utf8;
		Type: IncludeType;

		{
			position: src::Position,
			path: std::Utf8&&,
			type: IncludeType
		}->	Error(position)
		:	Include(&&path),
			Type(type);

		# FINAL print_msg(o: std::io::OStream &) VOID
		{
			o.write_all(Type.NAME(), " include '", Include!, "' not found");
		}
	}

	# relative_path(relative: String#&) std::Utf8
		:= util::absolute_file(
			util::concat_paths(
				util::parent_dir(Source->Name!),
				relative)!);

	STATIC cmp(a: std::Utf8 #&, b: File \) INLINE
		::= a.cmp(b->Source->Name);
	STATIC cmp(a: std::[CHAR#]Buffer #&, b: File \) INLINE
		::= std::str::cmp(a, b->Source->Name!);
	STATIC cmp(a: File \, b: File \) INLINE
		::= a->Source->Name.cmp(b->Source->Name);
}