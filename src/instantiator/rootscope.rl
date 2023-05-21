INCLUDE "cache.rl"

::rlc::instantiator::detail RootScope
{
	Prev: resolver::Config::RootScope #\;
	Cache: instantiator::Cache;

	PRIVATE DummySrc: src::File - std::Shared;
	PRIVATE Scoper: scoper::Config;
	PRIVATE Cli: cli::Console \;

	{prev: resolver::Config::RootScope #\, cli: ::cli::Console \}:
		Prev := prev,
		DummySrc := :fromString(
			<std::str::CV>("<instantiator arguments>"),
			<std::str::CV>("")),
		Scoper := BARE,
		Cli := cli;

	// Does NOT allow template arguments.
	# find_by_name(name: std::Str) {
		ast::[resolver::Config]Instantiable #\ -std::Vec,
		ast::[resolver::Config]ScopeItem #*
	} {
		DummySrc!.Contents := &&name;
		p: parser::Parser(:<>(DummySrc), Cli);
		t: parser::Trace(&p, "instantiator::RootScope::find()");
		pFile: ast::[parser::Config]File (BARE);
		pFile.Source := :<>(DummySrc);
		psym: ast::[parser::Config]Symbol (BARE);
		IF(!parser::symbol::parse(p, psym))
			p.fail("input not a symbol");

		FOR(c ::= psym.Children.start())
			IF(c!.Templates)
				p.fail("no templates allowed");

		scoper: scoper::Config (BARE);
		ctx ::= <scoper::Config::Context>(&pFile, &scoper);
		ssym ::= ctx.transform_symbol(psym, :_);

		scope: ast::[resolver::Config]ScopeBase #* := &Prev->ScopeItems;
		item: ast::[resolver::Config]ScopeItem #*;

		trace: ast::[resolver::Config]Instantiable #\ -std::Vec;
		FOR(ch ::= ssym.Children.start())
		{
			IF(!scope)
				= (BARE, NULL);
			IF(inst ::= <<ast::[resolver::Config]Instantiable #*>>(item))
				trace += inst;
			IF!(item := scope->scope_item(ch!.Name))
				= (BARE, NULL);
			scope := <<ast::[resolver::Config]ScopeBase #*>>(item);
		}
		= (&&trace, item);
	}
}