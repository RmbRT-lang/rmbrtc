INCLUDE "../ast/symbol.rl"
INCLUDE "parser.rl"


::rlc::parser::symbol [Symbol:TYPE] parse(p: Parser&, out: Symbol! &) BOOL
{
	t: Trace(&p, "symbol");

	out.IsRoot := p.consume(:doubleColon);
	expect ::= out.IsRoot;

	DO(child: Symbol::Child+ (BARE))
	{
		IF(!parse_child(p, child))
		{
			IF(expect)
				p.fail("expected symbol child");
			RETURN FALSE;
		}

		out.Children += &&child;
	} FOR(p.consume(:doubleColon); expect := TRUE)

	RETURN TRUE;
}

::rlc::parser::symbol [SymbolChild:TYPE] parse_child(
	p: Parser&,
	out: SymbolChild! &
) BOOL
{
	IF(p.consume(:bracketOpen))
	{
		IF(!p.consume(:bracketClose))
		{
			DO()
			{
				tArg: ast::[Config]TemplateArg;
				IF(p.consume(:semicolon))
					{ ; }
				ELSE IF(p.consume(:hash))
					DO()
					{
						IF:!(arg ::= expression::parse(p))
							p.fail("expected expression");
						tArg += :!(&&arg);
					} WHILE(p.consume(:comma))
				ELSE
					DO()
					{
						IF:!(arg ::= type::parse(p))
							p.fail("expected type");
						tArg += :!(&&arg);
					} WHILE(p.consume(:comma))
				out.Templates += &&tArg;
			} WHILE(p.consume(:semicolon))
			p.expect(:bracketClose);
		}
		id ::= p.expect(:identifier);
		(out.Name, out.Position) := (id.Content, id.Position);
		= TRUE;
	} ELSE IF(id ::= p.consume(:identifier))
	{
		(out.Name, out.Position) := (id->Content, id->Position);
		= TRUE;
	}

	= FALSE;
}