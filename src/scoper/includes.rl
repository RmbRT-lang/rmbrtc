::rlc::scoper::include
{
	/// Resolves a path relative to a file. Throws if the resulting file does not exist.
	::help relative_path(
		base_file: std::str::CV,
		relative: std::str::CV
	) std::Utf8
		:= util::absolute_file(
			util::concat_paths(
				util::parent_dir(base_file),
				relative)!);

	/// Resolves an include belonging to a file. Throws an IncludeNotFound if the include could not be resolved.
	resolve(
		base_file: std::str::CV,
		inc: parser::Include #&,
		source: src::File #&
	) std::Str
	{
		path ::= literal::string(inc->Token, source);
		TRY SWITCH(type ::= inc!.Type)
		{
		:relative: = relative_path(path!);
		:global: = find_global(path!);
		}
		CATCH(std::io::FileNotFound&)
			THROW <IncludeNotFound>(inc!.Token.Position, &&path, inc!.Type);
	}

	/// Finds a file belonging to a global include path.
	find_global(
		path: std::[CHAR#]Buffer #&,
		globals: std::Str - std::Vec#&) std::Utf8
	{
		FOR(inc ::= globals.start(); inc; ++inc)
			TRY RETURN util::absolute_file(
				util::concat_paths(inc!, path)!);
			CATCH() { ; }

		THROW <std::io::FileNotFound>(path++);
	}


::rlc::scoper IncludeNotFound -> Error
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
		o.write_all(<CHAR#\>(Type), " include '", Include!, "' not found");
	}
}