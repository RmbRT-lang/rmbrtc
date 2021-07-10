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
	SWITCH(t ::= <<scoper::ScopeItem #\>>(v)->type())
	{
	DEFAULT:
		THROW <std::err::Unimplemented>(t.NAME());
	CASE :namespace:
		RETURN std::[Namespace]new(<<scoper::Namespace #\>>(v), cache);
	CASE :typedef:
		RETURN std::[GlobalTypedef]new(<<scoper::GlobalTypedef #\>>(v), cache);
	CASE :function:
		RETURN std::[GlobalFunction]new(<<scoper::GlobalFunction #\>>(v), cache);
	CASE :variable:
		RETURN std::[GlobalVariable]new(<<scoper::GlobalVariable #\>>(v), cache);
	CASE :class:
		RETURN std::[GlobalClass]new(<<scoper::GlobalClass #\>>(v), cache);
	CASE :mask:
		RETURN std::[GlobalMask]new(<<scoper::GlobalMask #\>>(v), cache);
	CASE :rawtype:
		RETURN std::[GlobalRawtype]new(<<scoper::GlobalRawtype #\>>(v), cache);
	CASE :union:
		RETURN std::[GlobalUnion]new(<<scoper::GlobalUnion #\>>(v), cache);
	CASE :enum:
		RETURN std::[GlobalEnum]new(<<scoper::GlobalEnum #\>>(v), cache);
	CASE :externSymbol:
		RETURN std::[ExternSymbol]new(<<scoper::ExternSymbol #\>>(v), cache);
	CASE :test:
		RETURN std::[Test]new(<<scoper::Test #\>>(v), cache);
	}
}