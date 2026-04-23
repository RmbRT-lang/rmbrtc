//INCLUDE "typededupler.rl"
INCLUDE "postparser.rl"

::rlc::compiler Stage2 {
	Build: compiler::Build \;

	Parser: CodePostParser;

	{build: compiler::Build \}:
		Build := build,
		Parser (BARE);

	run(rootScope: scoper::Namespace, fileTokens: tok::FileTokenView[#], stats: compiler::Stats) VOID
	{
		Parser.{&rootScope, fileTokens};

		start ::= NOW;
		Parser.post_parse_ns(&rootScope);
		end ::= NOW;

		delta ::= end - start;

		lines ::= stats.lines;
		size ::= stats.size;

		lines_per_second ::= (GIGA * lines) / (delta);
		target: U8 := MEGA; // million lines per second.
		budget ::= (10000 * target) / lines_per_second;

		term::info(NULL,
			"Phase 2: ", std::io::format::dec(delta / MEGA), ".", std::io::format::dec_x((delta % MEGA) / 1000, 3), "ms",
			", ", std::io::format::dec(Parser.CurrentRequest), " types parsed, ",
			std::io::format::dec((lines_per_second + 500) / MEGA), ".", std::io::format::dec_x(((lines_per_second + 500) % MEGA) / 1000, 3), "ML/s, ",
			std::io::format::dec(budget / 100), ".", std::io::format::dec_x(budget % 100, 2), "% of budget");
	}
}