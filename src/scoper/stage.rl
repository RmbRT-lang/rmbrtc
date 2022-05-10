INCLUDE "../parser/stage.rl"
INCLUDE "../util/file.rl"

::rlc::scoper Config
{
	ParsedRegistry: ast::[parser::Config]FileRegistry \;
	Registry: ast::[Config]FileRegistry;

	TYPE Previous := ast::[parser::Config]File #\;
	TYPE Context := Config \;

	{prev: parser::Config \}:
		ParsedRegistry(&prev->Registry),
		Registry(&THIS);
	

	TYPE Includes := ast::[Config] File #\ - std::Vec;

	transform_includes(
		out: Includes&,
		parsed: ast::[parser::Config]File \
	) VOID
	{
		FOR(inc ::= out->Includes.start(); inc; ++inc)
		{
			SWITCH(inc!.Type)
			{
			:relative:
			{
				relative_path ::= parse_string(inc!.Token.Content);
				directory ::= util::parent_dir(parsed->Name);
				conc ::= util::concat_paths(directory, relative_path!);
				TRY
				{
					resolved_path ::= util::absolute_file(conc!);
				} CATCH()
				{
					THROW <rlc::Error>(inc!.Token.Position);
				}
			}
			}
			resolved_path ::= 
			registry->get();
		}
	}

	transform_globals(
		out: ast::[Config]Global-std::DynVec&,
		p: ast::[parser::Config]File \
	) VOID
	{
		WHILE(glob ::= global::parse(*p))
			out += &&glob;

		IF(!p->eof())
		{
			p->fail("expected scope entry");
			DIE;
		}
	}

	create_file(file: std::str::CV#&) Config-ast::File \
	{
		s: src::File-std::Shared := :new(file);
		p: Parser(s!);
		= std::heap::[Config-ast::File]new(:transform(:nothing, &p));
	}
}