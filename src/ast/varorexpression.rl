::rlc::ast [Stage: TYPE] VarOrExpr VIRTUAL
{
	<<<
		p: [Stage::Prev+]VarOrExpr #\,
		f: Stage::PrevFile+,
		s: Stage &
	>>> THIS-std::Dyn
	{
		TYPE SWITCH(p)
		{
		[Stage::Prev+]Variable:
			= <<<[Stage]Variable>>>(<<[Stage::Prev+]Variable #\>>(p), f, s);
		[Stage::Prev+]Expression:
			= <<<[Stage]Expression>>>(<<[Stage::Prev+]Expression #\>>(p), f, s);
		}
	}
}