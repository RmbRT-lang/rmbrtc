INCLUDE "../ast/mask.rl"
INCLUDE "parser.rl"
INCLUDE "stage.rl"

::rlc::parser::mask
{
	parse(p: Parser&, out: Config-ast::Mask &) BOOL
	{
		IF(!p.consume(:mask))
			RETURN FALSE;

		t: Trace(&p, "mask");

		p.expect(:identifier, &out.Name);
		p.expect(:braceOpen);

		DO(default_visibility: Visibility := Visibility::public)
			IF(member ::= parser::member::parse_mask_member(p, default_visibility))
				Members += &&member;
			ELSE
				p.fail("expected member");
			WHILE(!p.consume(:braceClose))

		RETURN TRUE;
	}

	parse_global(p: Parser&, out: Config-ast::GlboalMask &) INLINE BOOL
		:= mask::parse(p, out);
}