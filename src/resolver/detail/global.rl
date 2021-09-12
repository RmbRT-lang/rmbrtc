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
	CASE scoper::Namespace:
		RETURN std::[Namespace]new(<<scoper::Namespace #\>>(v), cache);
	CASE scoper::GlobalTypedef:
		RETURN std::[GlobalTypedef]new(<<scoper::GlobalTypedef #\>>(v), cache);
	CASE scoper::GlobalFunction:
		RETURN std::[GlobalFunction]new(<<scoper::GlobalFunction #\>>(v), cache);
	CASE scoper::GlobalVariable:
		RETURN std::[GlobalVariable]new(<<scoper::GlobalVariable #\>>(v), cache);
	CASE scoper::GlobalClass:
		RETURN std::[GlobalClass]new(<<scoper::GlobalClass #\>>(v), cache);
	CASE scoper::GlobalMask:
		RETURN std::[GlobalMask]new(<<scoper::GlobalMask #\>>(v), cache);
	CASE scoper::GlobalRawtype:
		RETURN std::[GlobalRawtype]new(<<scoper::GlobalRawtype #\>>(v), cache);
	CASE scoper::GlobalUnion:
		RETURN std::[GlobalUnion]new(<<scoper::GlobalUnion #\>>(v), cache);
	CASE scoper::GlobalEnum:
		RETURN std::[GlobalEnum]new(<<scoper::GlobalEnum #\>>(v), cache);
	CASE scoper::ExternSymbol:
		RETURN std::[ExternSymbol]new(<<scoper::ExternSymbol #\>>(v), cache);
	CASE scoper::Test:
		RETURN std::[Test]new(<<scoper::Test #\>>(v), cache);
	}
}