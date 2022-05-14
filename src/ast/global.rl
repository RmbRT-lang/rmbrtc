/// A named entry in a namespace.
::rlc::ast [Stage: TYPE] Global VIRTUAL
{
	PRIVATE TYPE PrevFile := Stage::PrevFile!;
	<<<
		g: [Stage-Prev]Global #&,
		f: PrevFile #&
	>>> THIS - std::Dyn
	{
		TYPE SWITCH(g)
		{
		[Stage-ast::Prev]GlobalClass:
			= :dup(<[Stage]GlobalClass>(:transform(
				<<[Stage-ast::Prev]GlobalClass #&>>(*g), f)));
		[Stage-ast::Prev]GlobalRawtype:
			= :dup(<[Stage]GlobalRawtype>(:transform(
				<<[Stage-ast::Prev]GlobalRawtype #&>>(*g), f)));
		[Stage-ast::Prev]GlobalUnion:
			= :dup(<[Stage]GlobalUnion>(:transform(
				<<[Stage-ast::Prev]GlobalUnion #&>>(*g), f)));
		[Stage-ast::Prev]Namespace:
			= :dup(<[Stage]Namespace>(:transform(
				<<[Stage-ast::Prev]Namespace #&>>(*g), f)));
		[Stage-ast::Prev]GlobalEnum:
			= :dup(<[Stage]GlobalEnum>(:transform(
				<<[Stage-ast::Prev]GlobalEnum #&>>(*g), f)));
		[Stage-ast::Prev]ExternFunction:
			= :dup(<[Stage]ExternFunction>(:transform(
				<<[Stage-ast::Prev]ExternFunction #&>>(*g), f)));
		[Stage-ast::Prev]ExternVariable:
			= :dup(<[Stage]ExternVariable>(:transform(
				<<[Stage-ast::Prev]ExternVariable #&>>(*g), f)));
		[Stage-ast::Prev]GlobalVariable:
			= :dup(<[Stage]GlobalVariable>(:transform(
				<<[Stage-ast::Prev]GlobalVariable #&>>(*g), f)));
		[Stage-ast::Prev]GlobalFunction:
			= :dup(<[Stage]GlobalFunction>(:transform(
				<<[Stage-ast::Prev]GlobalFunction #&>>(*g), f)));
		}
	}
}