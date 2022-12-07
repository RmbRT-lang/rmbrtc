::rlc::ast [Stage: TYPE] VarOrExpr VIRTUAL
{
	<<<
		p: [Stage::Prev+]VarOrExpr #&,
		f: Stage::PrevFile+,
		s: Stage &,
		parent: [Stage]ScopeBase \
	>>> THIS-std::Dyn
	{
		TYPE SWITCH(p)
		{
		[Stage::Prev+]LocalVariable:
			= :a.[Stage]LocalVariable(:transform(>>p, f, s, parent));
		[Stage::Prev+]Expression:
			= :<>(<<<[Stage]Expression>>>(>>p, f, s, parent));
		}
	}
}