INCLUDE "variable.rl"
INCLUDE "expression.rl"
INCLUDE "symbol.rl"
INCLUDE "statement.rl"

INCLUDE 'std/vector'
INCLUDE 'std/memory'

::rlc::parser Constructor -> Member
{
	BaseInit
	{
		Base: Symbol;
		Arguments: std::[std::[Expression]Dynamic]Vector;
	}

	MemberInit
	{
		Member: src::String;
		Arguments: std::[std::[Expression]Dynamic]Vector;
	}

	Name: src::String; // Always {.
	Arguments: std::[LocalVariable]Vector;
	BaseInits: std::[BaseInit]Vector;
	MemberInits: std::[MemberInit]Vector;
	Body: std::[BlockStatement]Dynamic;
	Inline: bool;

	# FINAL type() Member::Type := :constructor;
	# FINAL name() src::String#& := Name;

	parse(p: Parser&) bool
	{
		IF(!p.consume(:braceOpen, &Name))
			RETURN FALSE;
		t: Trace(&p, "constructor");

		IF(!p.match(:braceClose))
			DO(arg: LocalVariable)
			{
				IF(!arg.parse_fn_arg(p))
					p.fail("expected argument");
				Arguments += &&arg;
			} WHILE(p.consume(:comma))

		p.expect(:braceClose);

		Inline := p.consume(:inline);

		IF(p.consume(:minusGreater))
			DO(init: BaseInit)
			{
				IF(!init.Base.parse(p))
					p.fail("expected base class name");
				DO()
				{
					IF(exp ::= Expression::parse(p))
						init.Arguments += :gc(exp);
					ELSE
						p.fail("expected expression");
				} WHILE(p.consume(:comma))
				p.expect(:parentheseClose);

			} WHILE(p.consume(:comma))

		IF(p.consume(:colon))
			DO(init: MemberInit)
			{
				p.expect(:identifier, &init.Member);
				p.expect(:parentheseOpen);
				DO()
				{
					IF(exp ::= Expression::parse(p))
						init.Arguments += :gc(exp);
					ELSE
						p.fail("expected expression");
				} WHILE(p.consume(:comma))
				p.expect(:parentheseClose);
			} WHILE(p.consume(:comma))

		IF(!p.consume(:semicolon))
		{
			body: BlockStatement;
			IF(!body.parse(p))
				p.fail("expected constructor body");
			Body := :gc(std::dup(&&body));
		}

		RETURN TRUE;
	}
}