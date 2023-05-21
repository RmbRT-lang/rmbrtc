::rlc::ast [Stage:TYPE] ExprOrStatement VIRTUAL
{
	<<<
		p: [Stage::Prev+]ExprOrStatement #&,
		ctx: Stage::Context+ #&
	>>> THIS-std::Val
	{
		TYPE SWITCH(p)
		{
		[Stage::Prev+]Expression:
			= :<>(<<<[Stage]Expression>>>(>>p, ctx));
		[Stage::Prev+]Statement:
			= :<>(<<<[Stage]Statement>>>(>>p, ctx));
		}
	}
}