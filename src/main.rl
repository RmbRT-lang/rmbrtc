INCLUDE "parser/file.rl"
INCLUDE "parser/variable.rl"
INCLUDE "parser/typedef.rl"
INCLUDE "parser/type.rl"
INCLUDE "parser/function.rl"
INCLUDE "parser/namespace.rl"
INCLUDE "parser/class.rl"
INCLUDE "parser/rawtype.rl"
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

	out ::= std::io::OStream::from(&std::io::out);
	TRY
	{
		f: rlc::parser::File(std::Utf8(argv[1], std::cstring));
		out.write("success\n");
	} CATCH(e: std::Error&)
	{
		e.print(out);
		printf("\n");
	}

	RETURN 0;
}