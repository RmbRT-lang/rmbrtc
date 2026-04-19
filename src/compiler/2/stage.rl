//INCLUDE "typededupler.rl"
INCLUDE "postparser.rl"

::rlc::compiler Stage2 {
	Build: compiler::Build \;

	Parser: CodePostParser;

	{build: compiler::Build \}:
		Build := build,
		Parser (BARE);

	run(rootScope: scoper::Namespace, fileTokens: tok::FileTokenView[#]) VOID
	{
		Parser.{&rootScope, fileTokens};

		Parser.post_parse_ns(&rootScope);
	}
}