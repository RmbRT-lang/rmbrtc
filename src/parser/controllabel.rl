::rlc::parser parse(p: Parser &, out: Stage-ast::ControlLabel) VOID
{
	IF(out.Exists := p.consume(:bracketOpen))
	{
		IF(!p.consume(:stringBacktick, &out.Name)
		&& !p.consume(:stringQuote, &out.Name))
			p.fail("expected \"\" or `` string");
		p.expect(:bracketClose);
	}
}