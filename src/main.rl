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

Cmp{ [T:TYPE] STATIC cmp(a: T, b: T!) ::= a-b; }

main(
	argc: INT,
	argv: CHAR **) INT
{
	IF(argc < 2)
	{
		std::io::out.print("expected arguments\n");
		RETURN 1;
	}

	out ::= <<<std::io::OStream>>>(&std::io::out);

	registry: rlc::scoper::FileRegistry;
	registry.LegacyScope := :create(NULL, NULL);

	cache: std::[rlc::scoper::ScopeItem \; rlc::resolver::ScopeItem - std::Dynamic; Cmp]Map;
	TRY
	{
		files: rlc::scoper::File \ - std::Vector;
		FOR(i ::= 1; i < argc; i++)
		{
			absolute ::= rlc::util::absolute_file(std::str::buf(argv[i]));
			files += registry.get(std::Utf8(absolute, :cstring).content());
		}
		done: std::[rlc::scoper::ScopeItem \; Cmp]VectorSet;
		FOR(f ::= files.start(); f; f++)
		{
			FOR(group ::= (*f)->Scope->Items.start(); group; group++)
				FOR(it ::= (*group)->Items.start(); it; it++)
					IF(!done.insert(*it))
						cache.insert(*it, :gc(rlc::resolver::ScopeItem::create(*it)));
		}
		out.write("success\n");
	} CATCH(e: rlc::scoper::Error &)
	{
		e.print(out, registry);
		out.write("\n");
	}
	(/CATCH(e: std::Error&)
	{
		e.print(out);
		out.write("\n");
	}/) CATCH(e: CHAR#\)
		out.write_all(e, "\n");
	FINALLY{;}

	RETURN 0;
}