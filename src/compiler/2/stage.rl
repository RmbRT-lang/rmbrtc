//INCLUDE "typededupler.rl"
INCLUDE "postparser.rl"

::rlc::compiler Stage2 {
	Build: compiler::Build \;

	Parser: CodePostParser;

	{build: compiler::Build \}:
		Build := build,
		Parser (BARE);

	run(stats: compiler::Stats) VOID
	{
		rootscope ::= stage1::parse::namespace(0);
		Parser.{rootscope, stage1::parse::FileTokens!};

		start ::= NOW;
		Parser.post_parse();
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
			std::io::format::dec(##stage1::parse::Types), " types, ",
			std::io::format::dec(##stage1::parse::Arguments), " signatures, ",
			std::io::format::dec(##stage1::parse::Returns), " returns, ",
			std::io::format::dec(##stage1::parse::Expressions), " exprs, ",
			std::io::format::dec(##stage1::parse::Bodies), " bodies, ",
			std::io::format::dec(##stage1::parse::SpecialCtorBodies), " special bodies, ",
			std::io::format::dec((lines_per_second + 500) / MEGA), ".", std::io::format::dec_x(((lines_per_second + 500) % MEGA) / 1000, 3), "ML/s, ",
			std::io::format::dec(budget / 100), ".", std::io::format::dec_x(budget % 100, 2), "% of budget");
	}
}