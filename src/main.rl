INCLUDE "scoper/fileregistry.rl"
INCLUDE "util/file.rl"
INCLUDE 'std/io/file'

main(
	argc: int,
	argv: char **) int
{
	IF(argc != 2)
	{
		std::io::out.print("expected 1 argument\n");
		RETURN 1;
	}

	out ::= std::io::OStream::FROM(&std::io::out);

	registry: rlc::scoper::FileRegistry;

	TRY
	{
		absolute ::= rlc::util::absolute_file(std::str::buf(argv[1]));
		registry.get(std::Utf8(absolute, std::cstring).content());
		out.write("success\n");
	} CATCH(e: std::Error&)
	{
		e.print(out);
		printf("\n");
	}

	RETURN 0;
}