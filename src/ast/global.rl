/// A named entry in a namespace.
::rlc::ast [Stage: TYPE] Global VIRTUAL
{
	<<<
		g: [Stage::Prev+]Global #&,
		ctx: Stage::Context+ &
	>>> THIS - std::Dyn
	{
		TYPE SWITCH(g)
		{
		[Stage::Prev+]Namespace:
			= :dup(<[Stage]Namespace>(:transform(
				<<[Stage::Prev+]Namespace #&>>(g), ctx)));
		[Stage::Prev+]GlobalFunction:
			= :dup(<[Stage]GlobalFunction>(:transform(
				<<[Stage::Prev+]GlobalFunction #&>>(g), ctx)));
		[Stage::Prev+]GlobalClass:
			= :dup(<[Stage]GlobalClass>(:transform(
				<<[Stage::Prev+]GlobalClass #&>>(g), ctx)));
		[Stage::Prev+]GlobalRawtype:
			= :dup(<[Stage]GlobalRawtype>(:transform(
				<<[Stage::Prev+]GlobalRawtype #&>>(g), ctx)));
		[Stage::Prev+]GlobalUnion:
			= :dup(<[Stage]GlobalUnion>(:transform(
				<<[Stage::Prev+]GlobalUnion #&>>(g), ctx)));
		[Stage::Prev+]GlobalEnum:
			= :dup(<[Stage]GlobalEnum>(:transform(
				<<[Stage::Prev+]GlobalEnum #&>>(g), ctx)));
		[Stage::Prev+]ExternFunction:
			= :dup(<[Stage]ExternFunction>(:transform(
				<<[Stage::Prev+]ExternFunction #&>>(g), ctx)));
		[Stage::Prev+]ExternVariable:
			= :dup(<[Stage]ExternVariable>(:transform(
				<<[Stage::Prev+]ExternVariable #&>>(g), ctx)));
		[Stage::Prev+]GlobalVariable:
			= :dup(<[Stage]GlobalVariable>(:transform(
				<<[Stage::Prev+]GlobalVariable #&>>(g), ctx)));
		}
	}
}