::rlc::ast [Stage:TYPE] ExprOrStatement VIRTUAL
{
	<<<
		p: [Stage::Prev+]ExprOrStatement #&,
		f: Stage::PrevFile+,
		s: Stage &,
		parent: [Stage]ScopeBase \
	>>> THIS-std::Dyn
	{
		TYPE SWITCH(p)
		{
		[Stage::Prev+]Expression:
			= :<>(<<<[Stage]Expression>>>(>>p, f, s, parent));
		[Stage::Prev+]Statement:
			= :<>(<<<[Stage]Statement>>>(>>p, f, s, parent));
		}
	}
}