INCLUDE "../src/file.rl"
INCLUDE "../ast/symbol.rl"
INCLUDE "../ast/global.rl"
INCLUDE "parser.rl"
INCLUDE "include.rl"
INCLUDE "global.rl"

::rlc::parser
{
	Config
	{
		TYPE PrevFile := Parser \;
		TYPE PrevScopeEntry := :nothing;
		TYPE PrevExpression := :nothing;
		TYPE Prev := Config!;
		TYPE Context := :nothing;

		Registry: ast::[Config]FileRegistry;
		Cli: ::cli::Console \;
		SourceFiles: src::File - std::SharedVec;

		{cli: ::cli::Console \}: Registry(&THIS), Cli := cli;

		TYPE Symbol := Config-ast::Symbol;
		TYPE String := src::String;
		TYPE CharLiteral := tok::Token;
		TYPE StringLiteral := tok::Token - std::Vec;
		TYPE Name := src::String;
		TYPE ControlLabelName := tok::Token;
		TYPE ControlLabelReference := tok::Token;
		TYPE Number := tok::Token;

		TYPE Inheritance := Symbol;
		TYPE MemberReference := Symbol::Child;
		TYPE MemberVariableReference := src::String;

		TYPE Includes := Include - std::Vec;
		TYPE RootScope := Config-ast::Global - std::ValVec;

		transform_includes(
			out: Includes&,
			ast::[THIS]File *,
			p: Parser \
		) VOID
		{
			i: parser::Include (BARE);
			WHILE(i.parse(*p))
				out += &&i;
		}

		transform_globals(
			out: RootScope&,
			p: Parser \
		) VOID
		{
			WHILE(glob ::= global::parse(*p))
				out += :!(&&glob);

			IF(!p->eof())
			{
				p->fail("expected scope entry");
				DIE;
			}
		}

		create_file(
			file: std::str::CV#&
		) Config-ast::File - std::Dyn
		{
			s: src::File#-std::Shared := :<>( SourceFiles += :a(file) );
			p: Parser(&&s, Cli);
			= :transform(&p, THIS);
		}
	}
}