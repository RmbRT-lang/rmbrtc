::rlc::ast [Stage: TYPE] TypeOrExpr VIRTUAL
{
	<<<
		p: [Stage::Prev+]TypeOrExpr #&,
		ctx: Stage::Context+ #&
	>>> THIS - std::Dyn
	{
		TYPE SWITCH(p)
		{
		[Stage::Prev+]Type:
			= :<>(<<<[Stage]Type>>>(>>p, ctx));
		[Stage::Prev+]Expression:
			= :<>(<<<[Stage]Expression>>>(>>p, ctx));
		}
	}
}