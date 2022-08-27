::rlc::ast [Stage: TYPE] TypeOrExpr VIRTUAL
{
	<<<
		p: [Stage::Prev+]TypeOrExpr #\,
		f: Stage::PrevFile+,
		s: Stage &
	>>> THIS - std::Dyn
	{
		TYPE SWITCH(p)
		{
		[Stage::Prev+]Type:
			= <<<[Stage]Type>>>(<<[Stage::Prev+]Type #\>>(p), f, s);
		[Stage::Prev+]Expression:
			= <<<[Stage]Expression>>>(<<[Stage::Prev+]Expression #\>>(p), f, s);
		}
	}
}