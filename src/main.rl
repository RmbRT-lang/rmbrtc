INCLUDE "compiler/c.rl"
INCLUDE "cli/cli.rl"
INCLUDE "error.rl"
INCLUDE 'std/io/file'
INCLUDE 'std/set'
INCLUDE 'std/map'


::app
{
	version: CHAR#[] := "pre-alpha";
	repo: CHAR#[] := "https://github.com/RmbRT-lang/rmbrtc";
}

main(
	argc: INT,
	argv: CHAR **) INT
{
	out ::= <<<std::io::OStream>>>(&std::io::out);
	cli::main := :plain(&out);

	IF(argc < 2)
	{
		cli::main.error(
			:w(argv[0]), ": expected arguments.\n"
		).info("run ", :e(argv[0]), :e(" help"), " for help.\n");
		RETURN 1;
	} ELSE IF(argc == 2)
	{
		STATIC cli: {std::str::CV, ((CHAR#\) VOID) *}#[](
			("help", &app::cmd::help),
			("version", &app::cmd::version),
			("license", &app::cmd::license)
		);
		FOR(i ::= 0; i < ##cli; i++)
			IF(cli[i].(0) == argv[1])
			{
				cli[i].(1)(argv[0]);
				= 0;
			}
	}

	type: std::str::CV := argv[1];
	buildType ::= rlc::compiler::BuildType::executable;

	flags: {rlc::compiler::BuildType, CHAR#\}#[](
		(:executable, "exe"),
		(:library, "lib"),
		(:sharedLibrary, "shared"),
		(:test, "test"), // build tests.
		(:checkSyntax, "syntax"), // only syntax.
		(:verifySimple, "quick-dry"), // simple symbol resolution, no templates.
		(:verifyFull, "dry") // templates.
	);

	flag ::= 1;

	FOR(i ::= 0; i < ##flags; i++)
		IF(type == flags[i].(1))
		{
			buildType := flags[i].(0);
			++flag;
			BREAK;
		}

	files: std::Str-std::Vec;
	FOR(;flag < argc; flag++)
		IF(<std::str::CV>(argv[flag]) == ":")
		{
			++flag;
			IF(argc == flag)
			{
				cli::main.error(
					:w(argv[0]), ": exected argument after ':'.\n"
				).info("run ", :e(argv[0]), :e(" help"), " for help.\n");
				= 1;
			} ELSE IF(argc > flag+1)
			{
				cli::main.error(
					:w(argv[0]), ": expected only one argument after ':'.\n"
				).info("run ", :e(argv[0]), :e(" help"), " for help.\n");
				= 1;
			}
			BREAK;
		} ELSE
		{
			files += argv[flag];
		}

	IF(!files)
	{
		cli::main.error(
			:w(argv[0]), ": no input files provided.\n"
		).info("run ", :e(argv[0]), :e(" help"), " for help.\n");
		= 1;
	}

	compiler: rlc::compiler::CCompiler;
	TRY
	{
		build: rlc::compiler::Build-std::Dyn;
		IF(flag < argc)
		{
			str: std::Str := <std::str::CV>(argv[argc-1]);
			b: rlc::compiler::Build := :withOutput(&&str, buildType);
			build := :gc(std::heap::[rlc::compiler::Build]new(&&b));
		}
		ELSE
			build := :new(buildType);
		//build->LegacyScoping := TRUE;

		cli::main.info("compiling ", :dec(##files), " files.\n");

		compiler.compile(&&files, &&*build);

		= 0;
	} CATCH(e: std::Error &)
		cli::main.error(:stream(e), "\n");
	CATCH(e: CHAR#\)
		cli::main.error(e, "\n");

	= 1;
}

::app::cmd help(exe: CHAR#\) VOID
{
	cli::main(
"Usage:\n"
"\t", :e(exe), " [help|license|version]\n"
"\t", :e(exe), " [<mode>] <source>... [: <output>]\n"
"\n"
"modes: exe|lib|shared|test|syntax|dry|quick-dry\n"
"\t", :e("exe"), ":       build an executable.\n"
"\t", :e("lib"), ":       build static library.\n"
"\t", :e("shared"), ":    build a shared library (DLL).\n"
"\t", :e("test"), ":      compile all tests into an executable.\n"
"\t", :e("syntax"), ":    only perform syntax checks.\n"
"\t", :e("dry"), ":       dry compilation without an output.\n"
"\t", :e("quick-dry"), ": check symbols, do not process templates or type system.\n"
"output:\n"
"\t" "for modes producing an output file, specifies the output. The default\n"
"\t" "output name is ", :w("rl-out"), " in the current working directory.\n"
	);
}

::app::cmd version(exe: CHAR#\) VOID
{
	cli::main(
		:e(exe), " - RmbRT language compiler (", :w(app::version), ")\n"
		"<", :w(app::repo), ">\n");
}

::app::cmd license(exe: CHAR#\) VOID
{
	version(exe);
	cli::main(
"\n"
"This program is free software: you can redistribute it and/or modify\n"
"it under the terms of the GNU Affero General Public License as published by\n"
"the Free Software Foundation, either version 3 of the License, or\n"
"(at your option) any later version.\n"
"\n"
"This program is distributed in the hope that it will be useful,\n"
"but WITHOUT ANY WARRANTY; without even the implied warranty of\n"
"MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the\n"
"GNU Affero General Public License for more details.\n"
"\n"
"You should have received a copy of the GNU Affero General Public License\n"
"along with this program.  If not, see <https://www.gnu.org/licenses/>.\n"
		);
}