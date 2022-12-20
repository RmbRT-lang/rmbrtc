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

		out.Size := expression::parse_x(p);

		IF(p.consume(:comma))
			out.Alignment := expression::parse_x(p);

		p.expect(:parentheseClose);

		out.Name := p.expect(:identifier).Content;

		IF(p.consume(:semicolon))
			= TRUE;

		p.expect(:braceOpen);

		visibility ::= Visibility::public;
		WHILE(member ::= member::parse_rawtype_member(p, visibility))
			out.add_member(:!(&&member));

		p.expect(:braceClose);

		= TRUE;
	}
	
	parse_global(p: Parser &, out: ast::[Config]GlobalRawtype &) BOOL INLINE
		:= parse(p, out);
	parse_member(p: Parser &, out: ast::[Config]MemberRawtype &) BOOL INLINE
		:= parse(p, out);
}