INCLUDE "../parser/stage.rl"
INCLUDE "../util/file.rl"
INCLUDE "../ast/test.rl"
INCLUDE "includes.rl"
INCLUDE "../ast/scopeitem.rl"
INCLUDE "../ast/cache.rl"

INCLUDE 'std/heaped'

::rlc::scoper Config
{
	ParsedRegistry: ast::[parser::Config]FileRegistry \;
	Registry: ast::[THIS]FileRegistry;
	IncludeDirs: std::Str - std::Buffer;

	MSIs: ast::[THIS; ast::[THIS]MergeableScopeItem]Cache - std::Heaped;

	TYPE Prev := parser::Config;
	TYPE PrevFile := ast::[parser::Config]File #\;
	TYPE Context := Config \;
	TYPE Includes := Config-ast::File \-std::Vec;
	TYPE Name := std::str::CV;
	TYPE String := std::Str;
	TYPE Inheritance := THIS-ast::Symbol;
	
	RootScope
	{
		ScopeItems: std::[std::str::CV; ast::[Config]ScopeItem]AutoDynMap;
		Tests: ast::[Config]Test - std::Vec;
	}

	{prev: parser::Config \}:
		ParsedRegistry(&prev->Registry),
		Registry(&THIS);

	transform_name(p: Prev::Name+ #&, f: PrevFile) Name INLINE
		:= f->Source->content(p)++;

	transform_includes(
		out: Includes&,
		parsed: ast::[parser::Config]File \
	) VOID
	{
		FOR(inc ::= parsed->Includes.start())
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
				conv ::= <<<Config-ast::ScopeItem>>>(*s, p, THIS);
				out.ScopeItems.insert(conv->Name!, &&conv);
			} ELSE
			{
				test ::= <<parser::Config-ast::Test #\>>(g!);
				out.Tests += :transform(*test, p, THIS);
			}
		}
	}

	create_file(file: std::str::CV#&) THIS-ast::File - std::Dyn
		:= :a(:transform(ParsedRegistry->get(file), THIS));
}