::rlc::ast [Stage: TYPE] TypeOrExpr VIRTUAL
{
	<<<
		p: [Stage::Prev+]TypeOrExpr #&,
		f: Stage::PrevFile+,
		s: Stage &,
		parent: [Stage]ScopeBase \
	>>> THIS - std::Dyn
	{
		TYPE SWITCH(p)
		{
		[Stage::Prev+]Type:
			= :<>(<<<[Stage]Type>>>(>>p, f, s, parent));
		[Stage::Prev+]Expression:
			= :<>(<<<[Stage]Expression>>>(>>p, f, s, parent));
		}
	}
}