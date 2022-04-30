::rlc::parser::extern parse(p: Parser &, out: ExternSymbol &) BOOL
{
	IF(!p.consume(:extern))
		RETURN FALSE;

	t: Trace(&p, "external symbol");
	IF(p.match_ahead(:colon))
	{
		var: GlobalVariable;
		IF(!variable::parse_extern(p, var))
			p.fail("expected variable");
		out.Name := var.Name;
		out.Symbol := :gc(std::dup(&&var));
	} ELSE
	{
		f: GlobalFunction;
		IF(!function::parse_extern(p, f))
			p.fail("expected function");
		out.Name := f.Name;
		out.Symbol := :gc(std::dup(&&f));
	}

	RETURN TRUE;
}