INCLUDE "compiler.rl"
INCLUDE "../ast/fileregistry.rl"
INCLUDE "../util/file.rl"
INCLUDE "../ast/symbol.rl"
INCLUDE 'std/streambuffer'
INCLUDE 'std/vector'
INCLUDE 'std/set'

INCLUDE "../parser/templatedecl.rl"
INCLUDE "../parser/type.rl"
INCLUDE "../parser/stage.rl"
INCLUDE "../scoper/stage.rl"
INCLUDE "../resolver/stage.rl"
INCLUDE "../instantiator/stage.rl"
INCLUDE "../instantiator/rootscope.rl"
INCLUDE "../c/cprinter.rl"

::rlc::compiler CCompiler -> Compiler
{
	Parser: rlc::parser::Config;
	Scoper: rlc::scoper::Config - std::DynOpt;
	Resolver: rlc::resolver::Config - std::DynOpt;
	Instantiator: rlc::instantiator::Config - std::DynOpt;
	Cli: cli::Console \;

	{cli: ::cli::Console \}: Parser(cli), Cli := cli;

	FINAL compile(
		files: std::Str - std::Vec,
		build: Build
	) VOID
	{
		parsed: parser::Config - ast::File \ - std::VecSet;

		/// Parse all code first.
		FOR(f ::= files.start())
			parsed += Parser.Registry.get(util::absolute_file(f!));

		IF(build.Type == :checkSyntax)
			RETURN;

		/// Parse included files.
		Scoper := :a(&Parser, build.IncludePaths!);
		Scoper!.transform();

		IF(build.Type == :createAST)
			RETURN;

		Resolver := :a(Scoper!);
		Resolver!.transform();

		Instantiator := :a(Resolver!, Cli, :a());
		/// Seed instantiator with items to process.
		SWITCH(build.Type)
		{
		:verifySimple: RETURN;
		:executable:
		{
			entry ::= build.EntryPoints.start();
			Instantiator!.generate_entry_point_by_name(entry ?? entry! : "main");
		}
		:library,
		:sharedLibrary:
		{
			IF(entry ::= build.EntryPoints.start())
				FOR(entry) Instantiator!.generate_entry_point_by_name(entry!);
			ELSE
				Instantiator!.generate_everything();
		}
		:test:
		{
			Instantiator!.generate_tests();
		}
		:verifyFull:
		{
			Instantiator!.generate_everything();
		}
		}

		IF(!build.Output)
			RETURN;
		DIE "outputs not implemented";
	}
}