INCLUDE "scoper/fileregistry.rl"
INCLUDE "scoper/error.rl"
INCLUDE "resolver/detail/scopeitem.rl"
INCLUDE "resolver/detail/expression.rl"
INCLUDE "resolver/detail/global.rl"
INCLUDE "resolver/detail/member.rl"
INCLUDE "resolver/detail/statement.rl"
INCLUDE "resolver/detail/type.rl"
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


	registry: rlc::scoper::FileRegistry;
	registry.LegacyScope := :create(NULL, NULL);

	cache: rlc::resolver::Cache;
	TRY
	{
		files: rlc::scoper::File \ - std::Vector;
		FOR(i ::= 1; i < argc; i++)
		{
			absolute ::= rlc::util::absolute_file(std::str::buf(argv[i]));
			files += registry.get(std::Utf8(absolute, :cstring).content());
		}
		FOR(f ::= files.start(); f; f++)
		{
			FOR(group ::= (*f)->Scope->Items.start(); group; group++)
				FOR(it ::= (*group)->Items.start(); it; it++)
					cache += *it;
		}
		out.write("success\n");
	} CATCH(e: rlc::scoper::Error &)
	{
		e.print(out, registry);
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
	FINALLY{;}

	RETURN 0;
}