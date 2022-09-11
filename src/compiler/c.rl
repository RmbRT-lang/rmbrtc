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

::rlc::compiler CCompiler -> Compiler
{
	Parser: rlc::parser::Config;
	FINAL compile(
		files: std::Str - std::Vec,
		build: Build
	) VOID
	{
		parsed: parser::Config - ast::File \ - std::NatVecSet;

		// Parse all code first.
		FOR(f ::= files.start())
			parsed += Parser.Registry.get(util::absolute_file(f!));

		IF(build.Type == :checkSyntax)
			RETURN;

		scoper: rlc::scoper::Config(&Parser, build.IncludePaths!);
		scoped: rlc::scoper::Config - ast::File \ - std::NatVecSet;

		printf("%zu files recursively scoped\n", ##scoper.Registry);

		IF(build.Type == :createAST)
			RETURN;
(/
		// Resolve all references.
		resolved: resolver::Cache;
		FOR(f ::= scoped.start())
			FOR(group ::= f!->Scope->Items.start())
				FOR(it ::= group!->Items.start())
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
			FOR ["main"] (f ::= scoped.start())
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
			FOR(f ::= scoped.start())
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