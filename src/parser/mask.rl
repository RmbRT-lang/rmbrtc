INCLUDE "../ast/mask.rl"
INCLUDE "parser.rl"
INCLUDE "stage.rl"

::rlc::parser::mask
{
	parse(p: Parser&, out: ast::[Config]Mask &) BOOL
	{
		IF(tok ::= p.consume(:mask))
			out.Position := tok->Position;
		ELSE = FALSE;

		t: Trace(&p, "mask");

		out.Name := p.expect(:identifier).Content;
		p.expect(:braceOpen);

		DO(default_visibility: Visibility := Visibility::public)
			IF(member ::= parser::member::parse_mask_member(p, default_visibility))
				out.Members += :!(&&member);
			ELSE
				p.fail("expected member");
			WHILE(!p.consume(:braceClose))

		= TRUE;
	}

	parse_global(p: Parser&, out: ast::[Config]GlobalMask &) BOOL INLINE
		:= mask::parse(p, out);
}