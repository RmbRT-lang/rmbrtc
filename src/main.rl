INCLUDE "parser/file.rl"
INCLUDE "parser/namespace.rl"
INCLUDE "parser/type.rl"
INCLUDE 'std/io/file'

::namespace {}

a: VOID* := &b;
b: VOID* := &a;

main(
	argc: int,
	argv: char **) int
{
	IF(argc != 2)
	{
		std::io::out.print("expected 1 argument\n");
		RETURN 1;
	}

	f: rlc::parser::File(std::Utf8(argv[1], std::cstring));

	std::io::OStream::from(&std::io::out).write("success\n");

	RETURN 0;
}