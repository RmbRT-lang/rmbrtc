/// A named entry in a namespace.
::rlc::ast [Stage: TYPE] Global VIRTUAL
{
	<<<
		g: [Stage::Prev+]Global #&,
		ctx: Stage::Context+ #&
	>>> THIS - std::Val
	{
		TYPE SWITCH(g)
		{
		[Stage::Prev+]Namespace:
			= :a.[Stage]Namespace(:transform(>>g, ctx));
		[Stage::Prev+]GlobalFunction:
			= :a.[Stage]GlobalFunction(:transform(>>g, ctx));
		[Stage::Prev+]GlobalClass:
			= :a.[Stage]GlobalClass(:transform(>>g, ctx));
		[Stage::Prev+]GlobalRawtype:
			= :a.[Stage]GlobalRawtype(:transform(>>g, ctx));
		[Stage::Prev+]GlobalUnion:
			= :a.[Stage]GlobalUnion(:transform(>>g, ctx));
		[Stage::Prev+]GlobalEnum:
			= :a.[Stage]GlobalEnum(:transform(>>g, ctx));
		[Stage::Prev+]ExternFunction:
			= :a.[Stage]ExternFunction(:transform(>>g, ctx));
		[Stage::Prev+]ExternVariable:
			= :a.[Stage]ExternVariable(:transform(>>g, ctx));
		[Stage::Prev+]GlobalVariable:
			= :a.[Stage]GlobalVariable(:transform(>>g, ctx));
		[Stage::Prev+]GlobalTypedef:
			= :a.[Stage]GlobalTypedef(:transform(>>g, ctx));
		[Stage::Prev+]GlobalMask:
			= :a.[Stage]GlobalMask(:transform(>>g, ctx));
		}
	}
}