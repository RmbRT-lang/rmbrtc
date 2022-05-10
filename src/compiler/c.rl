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
	FINAL compile(
		files: std::Str - std::Vec,
		build: Build
	) VOID
	{
		parsed_registry: parser::Config-ast::FileRegistry(:nothing);

		// Processed input files.
		parsed: parser::Config - ast::File \ - std::NatVecSet;

		ASSERT(!build.LegacyScoping);

		// Parse all code first.
		FOR(f ::= files.start(); f; ++f)
			parsed += registry.get(util::absolute_file(f!));

		IF(build.Type == :checkSyntax)
			RETURN;

		scoped_registry: scoper::Config - ast::FileRegistry(&parsed_registry);
		scoped: scoper::Config - ast::File \ - std::NatVecSet;
		FOR(f ::= parsed.start(); f; ++f)
			scoped += scoped_registry->get(f->Name!);

(/
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
		/)
		DIE "not implemented";
	}
}