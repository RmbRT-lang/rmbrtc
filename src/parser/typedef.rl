INCLUDE "stage.rl"
INCLUDE "../ast/typedef.rl"

::rlc::parser::typedef
{
	parse(p: Parser&, out: Config-ast::Typedef &) BOOL
	{
		IF(!p.consume(:type))
			RETURN FALSE;
		t: Trace(&p, "typedef");

		out.Name := p.expect(:identifier).Content;
		p.expect(:colonEqual);

		IF(t ::= type::parse(p))
			out.Type := :!(&&t);
		ELSE p.fail("expected type");

		p.expect(:semicolon);

		RETURN TRUE;
	}

	parse_global(p: Parser&, out: Config-ast::GlobalTypedef &) BOOL INLINE
		:= parse(p, out);
	parse_member(p: Parser&, out: Config-ast::MemberTypedef &) BOOL INLINE
		:= parse(p, out);
}