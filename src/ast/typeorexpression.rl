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

	# THIS <>(rhs: THIS #&) S1
	{
		SWITCH(s ::= TYPE(THIS) <> TYPE(rhs))
		{
		0: = cmp_typeorexpr_impl(rhs);
		-1, 1: = s;
		}
	}

	PRIVATE # ABSTRACT cmp_typeorexpr_impl(THIS #&) S1;
}