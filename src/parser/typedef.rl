INCLUDE "stage.rl"
INCLUDE "../ast/typedef.rl"

::rlc::parser::typedef
{
	parse(p: Parser&, out: Config-ast::Typedef &) BOOL
	{
		IF(!p.consume(:type))
			RETURN FALSE;
		t: Trace(&p, "typedef");

		name: tok::Token;
		p.expect(:identifier, &name);
		out.Name := name.Content;
		p.expect(:colonEqual);

		out.Type := type::parse(p);
		IF(!out.Type)
			p.fail("expected type");

		p.expect(:semicolon);

		RETURN TRUE;
	}

	parse_global(p: Parser&, out: Config-ast::GlobalTypedef &) INLINE BOOL
		:= parse(p, out);
	parse_member(p: Parser&, out: Config-ast::MemberTypedef &) INLINE BOOL
		:= parse(p, out);
}