::rlc::ast [Stage: TYPE] VarOrExpr VIRTUAL
{
	<<<
		p: [Stage::Prev+]VarOrExpr #&,
		ctx: Stage::Context+ #&
	>>> THIS-std::Val
	{
		TYPE SWITCH(p)
		{
		[Stage::Prev+]LocalVariable:
			= :a.[Stage]LocalVariable(:transform(>>p, ctx));
		[Stage::Prev+]Expression:
			= :<>(<<<[Stage]Expression>>>(>>p, ctx));
		}
	}
}