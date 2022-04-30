INCLUDE "stage.rl"
INCLUDE "parser.rl"

::rlc::parser::symbol parse(p: Parser&, Stage::Symbol &) BOOL
{
	t: Trace(&p, "symbol");

	IsRoot := p.consume(:doubleColon);
	expect ::= IsRoot;

	DO(child: Child)
	{
		IF(!child.parse(p))
		{
			IF(expect)
				p.fail("expected symbol child");
			RETURN FALSE;
		}

		Children += &&child;
	} FOR(p.consume(:doubleColon); expect := TRUE)

	RETURN TRUE;
}

::rlc::parser::symbol parse_child(p: Parser&) BOOL
{
	IF(p.consume(:bracketOpen))
	{
		IF(!p.consume(:bracketClose))
		{
			DO()
			{
				tArg: [Stage]TemplateArg;
				IF(p.consume(:semicolon))
					{ ; }
				ELSE IF(p.consume(:hash))
					DO(arg: Expression *)
					{
						IF(!(arg := Expression::parse(p)))
							p.fail("expected expression");
						tArg += :gc(arg);
					} WHILE(p.consume(:comma))
				ELSE
					DO(arg: Type *)
					{
						IF(!(arg := Type::parse(p)))
							p.fail("expected type");
						tArg += :gc(arg);
					} WHILE(p.consume(:comma))
				Templates += &&tArg;
			} WHILE(p.consume(:semicolon))
			p.expect(:bracketClose);
		}
		p.expect(:identifier, &Name, &Position);
		RETURN TRUE;
	} ELSE
		RETURN p.consume(:identifier, &Name, &Position);
}