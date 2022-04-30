INCLUDE "parser.rl"
INCLUDE "../ast/constructor.rl"
INCLUDE "stage.rl"

::rlc::parser parse_constructor(p: Parser&, out: ast::[Config]Constructor) BOOL
{
	IF(!p.consume(:braceOpen, &out.Position))
		= FALSE;
	t: Trace(&p, "constructor");

	IF(!p.match(:braceClose))
		DO(arg: LocalVariable)
		{
			IF(!function::parse_arg(p, arg))
				p.fail("expected argument");
			out.Arguments += &&arg;
		} WHILE(p.consume(:comma))

	p.expect(:braceClose);

	out.Inline := p.consume(:inline);

	IF(p.consume(:minusGreater))
	{
		DO(init: BaseInit)
		{
			IF(!parse_symbol(p, init.Base))
				p.fail("expected base class name");
			p.expect(:parentheseOpen);
			IF(!p.consume(:parentheseClose))
			{
				DO()
				{
					IF(exp ::= expression::parse(p))
						init.Arguments += :gc(exp);
					ELSE
						p.fail("expected expression");
				} WHILE(p.consume(:comma))
				p.expect(:parentheseClose);
			}
			out.BaseInits += &&init;
		} WHILE(p.consume(:comma))
	}

	IF(p.consume(:colon))
	{
		DO(init: MemberInit)
		{
			p.expect(:identifier, &init.Member, &init.Position);
			p.expect(:parentheseOpen);
			IF(!p.consume(:parentheseClose))
			{
				DO()
				{
					IF(exp ::= expression::parse(p))
						init.Arguments += :gc(exp);
					ELSE
						p.fail("expected expression");
				} WHILE(p.consume(:comma))
				p.expect(:parentheseClose);
			}
			out.MemberInits += &&init;
		} WHILE(p.consume(:comma))
	}

	IF(!p.consume(:semicolon))
	{
		body: BlockStatement;
		IF(!body.parse(p))
			p.fail("expected constructor body");
		out.Body := std::gcdup(&&body);
	}

	= TRUE;
}