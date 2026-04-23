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

		start ::= NOW;
		Parser.post_parse_ns(&rootScope);
		end ::= NOW;

		delta ::= end - start;

		term::info(NULL, "Phase 2: ", std::io::format::dec(delta / MEGA), ".", std::io::format::dec_x((delta % MEGA) / 1000, 3), "ms");
	}
}