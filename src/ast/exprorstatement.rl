::rlc::ast [Stage:TYPE] ExprOrStatement VIRTUAL
{
	<<<
		p: [Stage::Prev+]ExprOrStatement #\,
		f: Stage::PrevFile+,
		s: Stage &
	>>> THIS-std::Dyn
	{
		TYPE SWITCH(p)
		{
		[Stage::Prev+]Expression:
			= <<<[Stage]Expression>>>(<<[Stage::Prev+]Expression #\>>(p), f, s);
		[Stage::Prev+]Statement:
			= <<<[Stage]Statement>>>(<<[Stage::Prev+]Statement #\>>(p), f, s);
		}
	}
}