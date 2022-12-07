/// A named entry in a namespace.
::rlc::ast [Stage: TYPE] Global VIRTUAL
{
	<<<
		g: [Stage::Prev+]Global #&,
		f: Stage::PrevFile+,
		s: Stage &,
		parent: [Stage]ScopeBase \
	>>> THIS - std::Dyn
	{
		TYPE SWITCH(g)
		{
		[Stage::Prev+]Namespace:
			= :a.[Stage]Namespace(:transform(>>g, f, s, parent));
		[Stage::Prev+]GlobalFunction:
			= :a.[Stage]GlobalFunction(:transform(>>g, f, s, parent));
		[Stage::Prev+]GlobalClass:
			= :a.[Stage]GlobalClass(:transform(>>g, f, s, parent));
		[Stage::Prev+]GlobalRawtype:
			= :a.[Stage]GlobalRawtype(:transform(>>g, f, s, parent));
		[Stage::Prev+]GlobalUnion:
			= :a.[Stage]GlobalUnion(:transform(>>g, f, s, parent));
		[Stage::Prev+]GlobalEnum:
			= :a.[Stage]GlobalEnum(:transform(>>g, f, s, parent));
		[Stage::Prev+]ExternFunction:
			= :a.[Stage]ExternFunction(:transform(>>g, f, s, parent));
		[Stage::Prev+]ExternVariable:
			= :a.[Stage]ExternVariable(:transform(>>g, f, s, parent));
		[Stage::Prev+]GlobalVariable:
			= :a.[Stage]GlobalVariable(:transform(>>g, f, s, parent));
		[Stage::Prev+]GlobalTypedef:
			= :a.[Stage]GlobalTypedef(:transform(>>g, f, s, parent));
		[Stage::Prev+]GlobalMask:
			= :a.[Stage]GlobalMask(:transform(>>g, f, s, parent));
		}
	}
}