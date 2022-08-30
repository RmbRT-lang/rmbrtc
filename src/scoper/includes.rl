INCLUDE "../error.rl"

INCLUDE "literals.rl"

::rlc::scoper::include
{
	/// Resolves a path relative to a file. Throws if the resulting file does not exist.
	::help relative_path(
		base_file: std::str::CV,
		relative: std::str::CV
	) std::Str
		:= util::absolute_file(
			util::concat_paths(
				util::parent_dir(base_file),
				relative)!);

	/// Resolves an include belonging to a file. Throws an IncludeNotFound if the include could not be resolved.
	resolve(
		base_file: std::str::CV,
		inc: parser::Include #&,
		source: src::File #&,
		globals: std::Str - std::Buffer#&
	) std::Str
	{
		path ::= literal::string(inc.Token, source);
		TRY SWITCH(type ::= inc.Type)
		{
		:relative: = help::relative_path(base_file, path!);
		:global: = find_global(path!, globals);
		}
		CATCH()
			THROW <NotFound>(inc!.Token.Position, &&path, inc!.Type);
	}

	/// Finds a file belonging to a global include path.
	find_global(
		path: std::[CHAR#]Buffer #&,
		globals: std::Str - std::Buffer#&) std::Str
	{
		ASSERT(##globals);
		FOR(inc ::= globals.start())
			TRY RETURN util::absolute_file(
				util::concat_paths(inc!, path)!);
			CATCH() {
				std::io::write(<<<std::io::OStream>>>(&std::io::out),
					"() could not find ", inc!++, "/", path++, "\n");
			}
			CATCH(f: std::io::FileNotFound &)
			{
				std::io::write(<<<std::io::OStream>>>(&std::io::out),
					:stream(f), "\n");
			}

		THROW;
	}

	NotFound -> Error
	{
		Include: std::Str;
		Type: IncludeType;

		{
			position: src::Position,
			path: std::Str&&,
			type: IncludeType
		}->	(position)
		:	Include(&&path),
			Type(type);

		# FINAL message(o: std::io::OStream &) VOID
		{
			std::io::write(o,
				<CHAR#\>(Type), " include '", Include!++, "' not found");
		}
	}
}