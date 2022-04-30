INCLUDE "stage.rl"

::rlc::parser::enum parse(p: Parser &, out: Enum &) BOOL
{
	IF(!p.consume(:enum, &out.Position))
		RETURN FALSE;

	t: Trace(&p, "enum");

	p.expect(:identifier, &out.Name);
	p.expect(:braceOpen);

	DO(c: Constant)
		DO()
		{
			p.expect(:identifier, &c.Name, &c.Position);
			out.Constants += &&c;
		} WHILE(p.consume(:colonEqual))
	FOR(p.consume(:comma); c.Value++)

	p.expect(:braceClose);
	RETURN TRUE;
}