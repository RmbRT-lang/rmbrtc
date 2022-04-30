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

::rlc::compiler CCompiler -> Compiler
{
	Registry: parser::Config-ast::FileRegistry;
	FINAL compile(
		files: std::Str - std::Vec,
		build: Build
	) VOID
	{
		// Processed input files.
		scoped: parser::Stage - ast::File \ - std::NatVectorSet;

		IF(build.LegacyScoping)
			Registry.LegacyScope := :create(NULL, NULL);

		build.AdditionalIncludePaths.append(Registry.IncludeDirs!, :move);
		Registry.IncludeDirs := &&build.AdditionalIncludePaths;

		// Parse all code first.
		FOR(f ::= files.start(); f; ++f)
		{
			abs ::= util::absolute_file(f!);
			scoped += Registry.get(<std::Str>(abs, :cstring)!);
		}

		IF(build.Type == :checkSyntax)
			RETURN;

		// Resolve all references.
		resolved: resolver::Cache;
		FOR(f ::= scoped.start(); f; ++f)
			FOR(group ::= f!->Scope->Items.start(); group; ++group)
				FOR(it ::= group!->Items.start(); it; ++it)
					resolved += it!;

		instances: instantiator::Cache(&resolved);
		SWITCH(build.Type)
		{
		DEFAULT: THROW <std::err::Unimplemented>(<CHAR#\>(build.Type));
		:verifySimple: RETURN;
		:executable:
		{
			mainFn: scoper::ScopeItem * := NULL;
			mainName ::= std::str::buf("main");
			FOR ["main"] (f ::= scoped.start(); f; ++f)
				IF(group ::= f!->Scope->find(mainName))
					TYPE SWITCH(group->Items[0]!)
					{
					scoper::Function:
						{
							ASSERT(1 == ##group->Items);
							IF(mainFn && mainFn != group->Items!.front()!)
								THROW <scoper::ItemMsgError>(
									group->Items!.front()!,
									Registry,
									"excess ::main function found.");
							mainFn := group->Items!.front()!;
						}
					}
			IF(!mainFn)
				THROW "no ::main function found.";

			instances.insert(NULL, resolved.get(mainFn));
		}
		:library,
		:sharedLibrary:
		{
			FOR(f ::= scoped.start(); f; ++f)
				instances.insert_all_untemplated(f!->Scope, resolved);
		}
		:test:
		{
			THROW <std::err::Unimplemented>("test build");
		}
		:verifyFull:
		{
			THROW <std::err::Unimplemented>("full verification");
		}
		}
	}
}