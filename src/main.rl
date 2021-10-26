INCLUDE "scoper/fileregistry.rl"
INCLUDE "scoper/error.rl"
INCLUDE "resolver/detail/scopeitem.rl"
INCLUDE "resolver/detail/expression.rl"
INCLUDE "resolver/detail/global.rl"
INCLUDE "resolver/detail/member.rl"
INCLUDE "resolver/detail/statement.rl"
INCLUDE "resolver/detail/type.rl"
INCLUDE "compiler/c.rl"
INCLUDE "util/file.rl"
INCLUDE 'std/io/file'
INCLUDE 'std/set'
INCLUDE 'std/map'

main(
	argc: INT,
	argv: CHAR **) INT
{
	out ::= <<<std::io::OStream>>>(&std::io::out);

	IF(argc < 2)
	{
		out.write_all(argv[0], ": expected arguments\n");
		RETURN 1;
	}

	type ::= std::str::buf(argv[1]);
	buildType ::= rlc::compiler::BuildType::executable;

	flags: {rlc::compiler::BuildType, CHAR#\}#[](
		(:executable, "exe"),
		(:library, "lib"),
		(:sharedLibrary, "shared"),
		(:test, "test"),
		(:checkSyntax, "syntax"),
		(:verifySimple, "quick-dry"),
		(:verifyFull, "dry")
	);

	flag ::= 1;

	FOR(i ::= 0; i < ##flags; i++)
		IF(!std::str::cmp(type, std::str::buf(flags[i].(1))))
		{
			buildType := flags[i].(0);
			++flag;
			BREAK;
		}

	files: std::Utf8-std::Vector;
	FOR(;flag < argc; flag++)
		IF(!std::str::cmp(argv[flag], ":"))
		{
			IF(argc == ++flag)
			{
				<<<std::io::OStream>>>(&std::io::err).write_all(
					argv[0],
					": exected argument after ':'.\n");
				RETURN 1;
			}
			BREAK;
		} ELSE
		{
			files += (argv[flag], :cstring);
		}


	compiler: rlc::compiler::CCompiler;
	TRY
	{
		build: rlc::compiler::Build-std::Dynamic;
		IF(flag < argc)
			build := :create((argv[argc-1], :cstring), buildType);
		ELSE
			build := :create(buildType);
		build->LegacyScoping := TRUE;

		compiler.compile(&&files, &&*build);
	} CATCH(e: rlc::scoper::Error &)
	{
		e.print(out, compiler.Registry);
		out.write("\n");
	}
	CATCH(e: rlc::tok::Error &)
	{
		e.print(out);
		out.write("\n");
	}
	CATCH(e: rlc::parser::Error &)
	{
		e.print(out);
		out.write("\n");
	}
	CATCH(e: rlc::scoper::IncompatibleOverloadError&)
	{
		e.print(out);
		out.write("\n");
	}
	CATCH(e: CHAR#\)
		out.write_all(e, "\n");

	RETURN 0;
}