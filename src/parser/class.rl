INCLUDE "stage.rl"

INCLUDE "parser.rl"
INCLUDE "member.rl"

INCLUDE "../ast/class.rl"

::rlc::parser::class
{
	parse(p: Parser &, out: Config-ast::Class &) BOOL
	{
		IF(!p.match(:identifier)
		|| (!p.match_ahead(:braceOpen)
			&& !p.match_ahead(:minusGreater)
			&& !p.match_ahead(:virtual)))
			RETURN FALSE;

		t: Trace(&p, "class");

		p.expect(:identifier, &Name);

		out.Virtual := p.consume(:virtual);

		IF(p.consume(:minusGreater))
			DO(i: ast::class::[Config]Inheritance)
			{
				i.parse(p);
				out.Inheritances += &&i;
			} WHILE(p.consume(:comma))

		p.expect(:braceOpen);

		default ::= Visibility::public;
		WHILE(member ::= parse_member(p, default))
			out.Members += :gc(member);

		p.expect(:braceClose);

		RETURN TRUE;
	}

	parse_inheritance(p: Parser &, out: ast::class::[Config]Inheritance &) VOID
	{
		STATIC lookup: {tok::Type, rlc::Visibility}#[](
			(:public, :public),
			(:private, :private),
			(:protected, :protected));

		t: Trace(&p, "inheritance");

		out.Visibility := :public;
		FOR(i ::= 0; i < ##lookup; i++)
			IF(p.consume(lookup[i].(0)))
			{
				out.Visibility := lookup[i].(1);
				BREAK;
			}

		out.IsVirtual := p.consume(:virtual);

		IF(!Type.parse(p))
			p.fail("expected type");
	}
}