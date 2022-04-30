INCLUDE "stage.rl"
INCLUDE "../ast/union.rl"

::rlc::parser::union
{
	parse(p: Parser &, out: ast::[Config]Union &) BOOL
	{
		IF(!p.consume(:union))
			RETURN FALSE;

		p.expect(:identifier, &Name);

		p.expect(:braceOpen);

		visibility ::= Visibility::public;
		WHILE(member ::= Member::parse(p, visibility))
			Members += :gc(member);

		p.expect(:braceClose);

		RETURN TRUE;
	}

	parse_global(p: Parser &, out: ast::[Config]GlobalUnion &) INLINE BOOL
		:= parse(p, out);

	parse_member(p: Parser &, out: ast::[Config]MemberUnion &) INLINE BOOL
		:= parse(p, out);
}