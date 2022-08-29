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
		[Stage::Prev+]LocalVariable:
			= :dup(<[Stage]LocalVariable>(:transform(
				<<[Stage::Prev+]LocalVariable #&>>(*p), f, s)));
		[Stage::Prev+]Expression:
			= <<<[Stage]Expression>>>(<<[Stage::Prev+]Expression #\>>(p), f, s);
		}
	}
}