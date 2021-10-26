INCLUDE "compiler.rl"
INCLUDE "../scoper/fileregistry.rl"
INCLUDE "../scoper/itemmsgerror.rl"
INCLUDE "../util/file.rl"
INCLUDE 'std/streambuffer'
INCLUDE 'std/vector'
INCLUDE 'std/set'

::rlc::compiler CCompiler -> Compiler
{
	Registry: scoper::FileRegistry;
	FINAL compile(
		files: std::Utf8 - std::Vector,
		build: Build
	) VOID
	{
		// Processed input files.
		scoped: scoper::File \ - std::NatVectorSet;

		IF(build.LegacyScoping)
			Registry.LegacyScope := :create(NULL, NULL);

		build.AdditionalIncludePaths.append(Registry.IncludeDirs!, :move);
		Registry.IncludeDirs := &&build.AdditionalIncludePaths;

		// Parse all code first.
		FOR(f ::= files.start(); f; ++f)
		{
			abs ::= util::absolute_file(f!);
			scoped += Registry.get(<std::Utf8>(abs, :cstring)!);
		}

		IF(build.Type == :checkSyntax)
			RETURN;

		// Resolve all references.
		resolved: resolver::Cache;
		FOR(f ::= scoped.start(); f; ++f)
			FOR(group ::= f!->Scope->Items.start(); group; ++group)
				FOR(it ::= group!->Items.start(); it; ++it)
					resolved += it!;

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

			THROW <std::err::Unimplemented>("executable code generation");
		}
		:library,
		:sharedLibrary:
		{
			THROW <std::err::Unimplemented>("library code generation");
		}
		:verifyFull:
		{
			THROW <std::err::Unimplemented>("full verification");
		}
		}
	}
}