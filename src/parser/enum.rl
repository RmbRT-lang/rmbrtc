INCLUDE "stage.rl"

INCLUDE "../ast/enum.rl"

::rlc::parser::enum parse(p: Parser &, out: ast::[Config]Enum &) BOOL
{
	IF(tok ::= p.consume(:enum))
		out.Position := tok->Position;
	ELSE = FALSE;

	t: Trace(&p, "enum");

	out.Name := p.expect(:identifier).Content;
	p.expect(:braceOpen);

	DO(c: ast::[Config]Enum::Constant)
		DO()
		{
			tok ::= p.expect(:identifier);
			(c.Name, c.Position) := (tok.Content, tok.Position);
			out.Constants += &&c;
		} WHILE(p.consume(:colonEqual))
	FOR(p.consume(:comma); c.Value++)

	p.expect(:braceClose);
	RETURN TRUE;
}