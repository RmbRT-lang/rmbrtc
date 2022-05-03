INCLUDE "../ast/rawtype.rl"
INCLUDE "member.rl"
INCLUDE "expression.rl"

::rlc::parser::rawtype
{
	parse(p: Parser &, out: ast::[Config]Rawtype &) BOOL
	{
		IF(tok ::= p.consume(:parentheseOpen))
			out.Position := tok->Position;
		ELSE = FALSE;

		t: Trace(&p, "rawtype");

		IF(!(out.Size := expression::parse(p)))
			p.fail("expected expression");

		IF(p.consume(:comma))
			IF(!(out.Alignment := expression::parse(p)))
				p.fail("expected expression");

		p.expect(:parentheseClose);

		out.Name := p.expect(:identifier).Content;

		IF(p.consume(:semicolon))
			= TRUE;

		p.expect(:braceOpen);

		visibility ::= Visibility::public;
		WHILE(member ::= member::parse_rawtype_member(p, visibility))
			out.Members += &&member;

		p.expect(:braceClose);

		= TRUE;
	}
	
	parse_global(p: Parser &, out: ast::[Config]GlobalRawtype &) INLINE BOOL
		:= parse(p, out);
	parse_member(p: Parser &, out: ast::[Config]MemberRawtype &) INLINE BOOL
		:= parse(p, out);
}