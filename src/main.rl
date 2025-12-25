INCLUDE 'os/file'
INCLUDE 'std/str'

INCLUDE "cli.rl"
INCLUDE "compiler/compiler.rl"
INCLUDE "tokeniser/tokeniser.rl"
INCLUDE "parser/parser.rl"
INCLUDE "mempool.rl"
INCLUDE "hashmap.rl"

::app
{
	version: CHAR#[#] := "pre-alpha";
	repo: CHAR#[#] := "https://github.com/RmbRT-lang/rmbrtc";
}

main(args: CHAR[#][#]) INT
{
	os::term::init();

	IF(##args == 1)
	{
		os::term::PrintLine_v(:style(:normal, :red),
			"expected arguments\n",
			:style(:normal, :cyan), "run ", :style(:bold, :same), args[0], " help",
			:style(:normal, :same), " for help.");
		= 1;
	}

	IF(##args == 2)
	{
		STATIC cli: {CHAR#[#], ((CHAR#[#]) VOID) *}#[?](
			("help",    &app::cmd::help),
			("version", &app::cmd::version),
			("license", &app::cmd::license)
		);
		FOR(i ::= 0; i < ##cli; i++)
			IF(std::str::eq(cli[i].(0), args[1]))
			{
				cli[i].(1)(args[0]);
				= 0;
			}
	}

	type ::= args[1];

	buildType ::= rlc::compiler::BuildType::executable;

	flags: CHAR#[#][TABLE rlc::compiler::BuildType]#(
		:executable("exe"),
		:library("lib"),
		:sharedLibrary("shared"),
		:test("test"), // build tests.
		:checkSyntax("syntax"), // only syntax.
		:createAST("create-ast"), // only create the AST and check includes.
		:verifySimple("quick-dry"), // simple symbol resolution, no templates.
		:verifyFull("dry") // templates.
	);

	flag ::= 1;

	FOR(i ::= 0; i < ##flags; i++)
		IF(std::str::eq(type, flags[i]))
		{
			buildType := >i;
			++flag;
			BREAK;
		}

	files: std::Str-std::Vec;
	FOR(;flag < ##args; flag++)
		IF(std::str::eq(args[flag], ":"))
		{
			++flag;
			IF(##args == flag)
			{
				os::term::Print_v(
					:style(:dim, :red), args[0],
					:style(:normal, :same), ": exected argument after ':'.\n",
					:style(:normal, :cyan), "run ", :style(:bold, :same), args[0], " help", :style(:normal, :same), " for help.\n");
				= 1;
			} ELSE IF(##args > flag+1)
			{
				os::term::Print_v(
					:style(:dim, :red), args[0], :style(:normal, :same),
						": expected only one argument after ':'.\n",
					:style(:normal, :cyan), "run ", :style(:bold, :same), args[0], " help", :style(:normal, :same), " for help.\n");
				= 1;
			}
			BREAK;
		} ELSE
		{
			files += args[flag];
		}

	IF(!files)
	{
		os::term::Print_v(
			:style(:dim, :red), args[0], :style(:normal, :same), ": no input files provided.\n",
			:style(:normal, :cyan), "run ", :style(:bold, :same), args[0], " help", :style(:normal, :same), " for help.\n");
		= 1;
	}

	rlc::tok::Tokeniser::init();

	//compiler: rlc::compiler::CCompiler (&cli::main);
	TRY
	{
		build: rlc::compiler::Build (BARE);
		IF(flag < ##args)
		{
			str: std::Str := >args[##args-1];
			build := :withOutput(&&str, buildType);
		}
		ELSE
			build := buildType;
		build.LegacyScoping := TRUE;


		compiler: rlc::compiler::Compiler;
		compiler.compile(files!, &&build);
		= 0;
	}
	CATCH(e: {WHERE, CHAR#[#]})
		term::error(e.(0), e.(1));
	//CATCH(e: CHAR #*) // "location: err"
	//	term::error(NULL, std::str::c(e[]));
	CATCH(e: {CHAR#\, CHAR#\})
		term::error(NULL, std::str::c(e.(0)[]), " (", std::str::c(e.(1)[]), ")");
	FINALLY{}

	= 1;
}

::app::cmd help(exe: CHAR#[#]) VOID
{
	os::term::Print_v(
"Usage:\n"
"\t", :style(:bold, :same), exe, :style(:normal, :same), " [help|license|version]\n"
"\t", :style(:bold, :same), exe, :style(:normal, :same), " [<mode>] <source>... [: <output>]\n"
"\n"
"modes: exe|lib|shared|test|syntax|dry|quick-dry\n"
"\t", :style(:bold, :same), "exe", :style(:normal, :same), ":       build an executable.\n"
"\t", :style(:bold, :same), "lib", :style(:normal, :same), ":       build static library.\n"
"\t", :style(:bold, :same), "shared", :style(:normal, :same), ":    build a shared library (DLL).\n"
"\t", :style(:bold, :same), "test", :style(:normal, :same), ":      compile all tests into an executable.\n"
"\t", :style(:bold, :same), "syntax", :style(:normal, :same), ":    only perform syntax checks.\n"
"\t", :style(:bold, :same), "dry", :style(:normal, :same), ":       dry compilation without an output.\n"
"\t", :style(:bold, :same), "quick-dry", :style(:normal, :same), ": check symbols, do not process templates or type system.\n"
"output:\n"
"\t" "for modes producing an output file, specifies the output. The default\n"
"\t" "output name is ", :style(:dim, :same), "rl-out", :style(:normal, :same), " in the current working directory.\n"
	);
}

::app::cmd version(exe: CHAR#[#]) VOID
{
	os::term::Print_v(
		:style(:bold, :same), exe, :style(:normal, :same), " - RmbRT language compiler (",
		:style(:dim, :same), app::version, :style(:normal, :same), ")\n"
		"<", :style(:dim, :same), app::repo, :style(:normal, :same), ">\n");
}

::app::cmd license(exe: CHAR#[#]) VOID
{
	version(exe);
	os::term::Print(
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