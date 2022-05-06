INCLUDE "stage.rl"
INCLUDE "../ast/union.rl"
INCLUDE "member.rl"

::rlc::parser::union
{
	parse(p: Parser &, out: ast::[Config]Union &) BOOL
	{
		IF(!p.consume(:union))
			= FALSE;

		tok ::= p.expect(:identifier);
		(out.Name, out.Position) := (tok.Content, tok.Position);

		p.expect(:braceOpen);

		visibility ::= Visibility::public;
		WHILE(member ::= member::parse_union_member(p, visibility))
			out.Members += &&member;

		p.expect(:braceClose);

		= TRUE;
	}

	parse_global(p: Parser &, out: ast::[Config]GlobalUnion &) BOOL INLINE
		:= parse(p, out);

	parse_member(p: Parser &, out: ast::[Config]MemberUnion &) BOOL INLINE
		:= parse(p, out);
}