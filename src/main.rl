INCLUDE "scoper/fileregistry.rl"
INCLUDE "util/file.rl"
INCLUDE 'std/io/file'

main(
	argc: int,
	argv: char **) int
{
	IF(argc < 2)
	{
		std::io::out.print("expected arguments\n");
		RETURN 1;
	}

	out ::= std::io::OStream::FROM(&std::io::out);

	registry: rlc::scoper::FileRegistry;
	registry.LegacyScope := :create(NULL, NULL);

	TRY
	{
		FOR(i ::= 1; i < argc; i++)
		{
			absolute ::= rlc::util::absolute_file(std::str::buf(argv[i]));
			registry.get(std::Utf8(absolute, :cstring).content());
		}
		out.write("success\n");
	} CATCH(e: std::Error&)
	{
		e.print(out);
		printf("\n");
	} CATCH(e: char#\)
		out.write_all(e, "\n");

	RETURN 0;
}