INCLUDE "../parser/stage.rl"
INCLUDE "../util/file.rl"

::rlc::scoper Config
{
	TYPE Previous := ast::[parser::Config]File #\;
	
	Context
	{
		ParsedRegistry: ast::[parser::Config]FileRegistry \;
	}

	TYPE Includes := ast::[Config] File #\ - std::Vec;

	STATIC transform_includes(
		out: Includes&,
		parsed: Previous,
		registry: Context
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
					inc!.Token.Position, 
				}
			}
			}
			resolved_path ::= 
			registry->get();
		}
	}

	STATIC transform_globals(
		out: ast::[Config]Global-std::DynVec&,
		:nothing,
		p: Parser \
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

	STATIC create_file(
		registry: Config-ast::FileRegistry &,
		file: std::str::CV#&
	) Config-ast::File \
	{
		s: src::File-std::Shared := :new(file);
		p: Parser(s!);
		= std::heap::[Config-ast::File]new(:transform(:nothing, &p));
	}
}