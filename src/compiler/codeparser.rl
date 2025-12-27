::rlc::compiler CodeParser
{
	Output {
		ScopeTree: U1;
	}

	TYPE Input := tok::FileTokens;

	handle_job(Input #&, Output *) VOID
	{
	}
}