INCLUDE "../global.rl"
INCLUDE "../namespace.rl"
INCLUDE "../typedef.rl"
INCLUDE "../function.rl"
INCLUDE "../variable.rl"
INCLUDE "../class.rl"
INCLUDE "../mask.rl"
INCLUDE "../rawtype.rl"
INCLUDE "../union.rl"
INCLUDE "../enum.rl"
INCLUDE "../extern.rl"
INCLUDE "../test.rl"
INCLUDE 'std/err/unimplemented'

::rlc::resolver::detail create_global(
	v: scoper::Global #\,
	cache: Cache &
) Global \
{
	TYPE SWITCH(v)
	{
	DEFAULT:
		THROW <std::err::Unimplemented>(TYPE(v));
	scoper::Namespace:
		RETURN std::[Namespace]new(<<scoper::Namespace #\>>(v), cache);
	scoper::GlobalTypedef:
		RETURN std::[GlobalTypedef]new(<<scoper::GlobalTypedef #\>>(v), cache);
	scoper::GlobalFunction:
		RETURN std::[GlobalFunction]new(<<scoper::GlobalFunction #\>>(v), cache);
	scoper::GlobalVariable:
		RETURN std::[GlobalVariable]new(<<scoper::GlobalVariable #\>>(v), cache);
	scoper::GlobalClass:
		RETURN std::[GlobalClass]new(<<scoper::GlobalClass #\>>(v), cache);
	scoper::GlobalMask:
		RETURN std::[GlobalMask]new(<<scoper::GlobalMask #\>>(v), cache);
	scoper::GlobalRawtype:
		RETURN std::[GlobalRawtype]new(<<scoper::GlobalRawtype #\>>(v), cache);
	scoper::GlobalUnion:
		RETURN std::[GlobalUnion]new(<<scoper::GlobalUnion #\>>(v), cache);
	scoper::GlobalEnum:
		RETURN std::[GlobalEnum]new(<<scoper::GlobalEnum #\>>(v), cache);
	scoper::ExternSymbol:
		RETURN std::[ExternSymbol]new(<<scoper::ExternSymbol #\>>(v), cache);
	scoper::Test:
		RETURN std::[Test]new(<<scoper::Test #\>>(v), cache);
	}
}