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

	Name: src::String; // Always CONSTRUCTOR.
	Arguments: std::[LocalVariable]Vector;
	BaseInits: std::[BaseInit]Vector;
	MemberInits: std::[MemberInit]Vector;
	Body: std::[BlockStatement]Dynamic;
	Inline: bool;

	# FINAL type() Member::Type := Member::Type::constructor;
	# FINAL name() src::String#& := Name;

	parse(p: Parser&) bool
	{
		IF(!p.consume(tok::Type::constructor, &Name))
			RETURN FALSE;
		t: Trace(&p, "constructor");

		p.expect(tok::Type::parentheseOpen);

		IF(!p.match(tok::Type::parentheseClose))
			DO(arg: LocalVariable)
			{
				IF(!arg.parse_fn_arg(p))
					p.fail("expected argument");
				Arguments.push_back(__cpp_std::move(arg));
			} WHILE(p.consume(tok::Type::comma))

		p.expect(tok::Type::parentheseClose);

		Inline := p.consume(tok::Type::inline);

		IF(p.consume(tok::Type::minusGreater))
			DO(init: BaseInit)
			{
				IF(!init.Base.parse(p))
					p.fail("expected base class name");
				DO()
				{
					IF(exp ::= Expression::parse(p))
						init.Arguments.push_back(exp);
					ELSE
						p.fail("expected expression");
				} WHILE(p.consume(tok::Type::comma))
				p.expect(tok::Type::parentheseClose);

			} WHILE(p.consume(tok::Type::comma))

		IF(p.consume(tok::Type::colon))
			DO(init: MemberInit)
			{
				p.expect(tok::Type::identifier, &init.Member);
				p.expect(tok::Type::parentheseOpen);
				DO()
				{
					IF(exp ::= Expression::parse(p))
						init.Arguments.push_back(exp);
					ELSE
						p.fail("expected expression");
				} WHILE(p.consume(tok::Type::comma))
				p.expect(tok::Type::parentheseClose);
			} WHILE(p.consume(tok::Type::comma))

		IF(!p.consume(tok::Type::semicolon))
		{
			body: BlockStatement;
			IF(!body.parse(p))
				p.fail("expected constructor body");
			Body := std::dup(__cpp_std::move(body));
		}

		RETURN TRUE;
	}
}