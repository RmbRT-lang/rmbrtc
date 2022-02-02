::rlc::instantiator::detail create_global(
	res: resolver::Global #\,
	scope: Scope #&
) Global \
{
	TYPE SWITCH(v)
	{
	DEFAULT:
		THROW <std::err::Unimplemented>(TYPE(v));
	resolver::Namespace:
		RETURN std::[Namespace]new(<<resolver::Namespace #\>>(v), cache);
	resolver::GlobalTypedef:
		RETURN std::[GlobalTypedef]new(<<resolver::GlobalTypedef #\>>(v), cache);
	resolver::GlobalFunction:
		RETURN std::[GlobalFunction]new(<<resolver::GlobalFunction #\>>(v), cache);
	resolver::GlobalVariable:
		RETURN std::[GlobalVariable]new(<<resolver::GlobalVariable #\>>(v), cache);
	resolver::GlobalClass:
		RETURN std::[GlobalClass]new(<<resolver::GlobalClass #\>>(v), cache);
	resolver::GlobalMask:
		RETURN std::[GlobalMask]new(<<resolver::GlobalMask #\>>(v), cache);
	resolver::GlobalRawtype:
		RETURN std::[GlobalRawtype]new(<<resolver::GlobalRawtype #\>>(v), cache);
	resolver::GlobalUnion:
		RETURN std::[GlobalUnion]new(<<resolver::GlobalUnion #\>>(v), cache);
	resolver::GlobalEnum:
		RETURN std::[GlobalEnum]new(<<resolver::GlobalEnum #\>>(v), cache);
	resolver::ExternSymbol:
		RETURN std::[ExternSymbol]new(<<resolver::ExternSymbol #\>>(v), cache);
	resolver::Test:
		RETURN std::[Test]new(<<resolver::Test #\>>(v), cache);
	}
}