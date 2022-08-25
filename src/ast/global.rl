/// A named entry in a namespace.
::rlc::ast [Stage: TYPE] Global VIRTUAL
{
	<<<
		g: [Stage::Prev+]Global #\,
		f: Stage::PrevFile+,
		s: Stage &
	>>> THIS - std::Dyn
	{
		TYPE SWITCH(g)
		{
		[Stage::Prev+]Namespace:
			= :dup(<[Stage]Namespace>(:transform(
				<<[Stage::Prev+]Namespace #&>>(*g), f, s)));
		[Stage::Prev+]GlobalFunction:
			= :dup(<[Stage]GlobalFunction>(:transform(
				<<[Stage::Prev+]GlobalFunction #&>>(*g), f, s)));
		[Stage::Prev+]GlobalClass:
			= :dup(<[Stage]GlobalClass>(:transform(
				<<[Stage::Prev+]GlobalClass #&>>(*g), f, s)));
		[Stage::Prev+]GlobalRawtype:
			= :dup(<[Stage]GlobalRawtype>(:transform(
				<<[Stage::Prev+]GlobalRawtype #&>>(*g), f, s)));
		[Stage::Prev+]GlobalUnion:
			= :dup(<[Stage]GlobalUnion>(:transform(
				<<[Stage::Prev+]GlobalUnion #&>>(*g), f, s)));
		[Stage::Prev+]GlobalEnum:
			= :dup(<[Stage]GlobalEnum>(:transform(
				<<[Stage::Prev+]GlobalEnum #&>>(*g), f, s)));
		[Stage::Prev+]ExternFunction:
			= :dup(<[Stage]ExternFunction>(:transform(
				<<[Stage::Prev+]ExternFunction #&>>(*g), f, s)));
		[Stage::Prev+]ExternVariable:
			= :dup(<[Stage]ExternVariable>(:transform(
				<<[Stage::Prev+]ExternVariable #&>>(*g), f, s)));
		[Stage::Prev+]GlobalVariable:
			= :dup(<[Stage]GlobalVariable>(:transform(
				<<[Stage::Prev+]GlobalVariable #&>>(*g), f, s)));
		}
	}
}