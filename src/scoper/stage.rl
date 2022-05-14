INCLUDE "../parser/stage.rl"
INCLUDE "../util/file.rl"
INCLUDE "../ast/test.rl"
INCLUDE "includes.rl"

::rlc::scoper Config
{
	ParsedRegistry: ast::[parser::Config]FileRegistry \;
	Registry: ast::[Config]FileRegistry;
	IncludeDirs: std::Str - std::Buffer;

	TYPE Prev := parser::Config;
	TYPE PrevFile := ast::[parser::Config]File #\;
	TYPE Context := Config \;
	TYPE Includes := Config-ast::File \-std::Vec;
	TYPE Name := std::str::CV;
	
	RootScope
	{
		ScopeItems: std::[std::str::CV; ast::[Config]ScopeItem]AutoDynMap;
		Tests: ast::[Config]Test - std::Vec;
	}

	{prev: parser::Config \}:
		ParsedRegistry(&prev->Registry),
		Registry(&THIS);

	transform_includes(
		out: Includes&,
		parsed: ast::[parser::Config]File \
	) VOID
	{
		FOR(inc ::= parsed->Includes.start(); inc; ++inc)
			out += Registry.get(
				include::resolve(
					parsed->Name!,
					inc!,
					*parsed->Source,
					IncludeDirs));
	}

	transform_globals(
		out: RootScope&,
		p: ast::[parser::Config]File #\
	) VOID
	{
		FOR(g ::= p->Globals.start(); g; ++g)
		{
			IF(s ::= <<parser::Config-ast::ScopeItem #\>>(g!))
			{
				conv ::= <<<Config-ast::ScopeItem>>>(*s, p);
				out.ScopeItems.insert(conv->Name!, &&conv);
			} ELSE
			{
				test ::= <<parser::Config-ast::Test #\>>(g!);
				out.Tests += :transform(*test, *p);
			}
		}
	}

	create_file(file: std::str::CV#&) Config-ast::File - std::Dyn
	{
		parsed ::= ParsedRegistry->get(file);
		= :new(:transform(parsed, &THIS));
	}
}