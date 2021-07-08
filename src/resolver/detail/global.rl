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
	v: scoper::Global #\
) Global \
{
	SWITCH(t ::= <<scoper::ScopeItem #\>>(v)->type())
	{
	DEFAULT:
		THROW <std::err::Unimplemented>(t.NAME());
	CASE :namespace:
		RETURN std::[Namespace]new(<<scoper::Namespace #\>>(v));
	CASE :typedef:
		RETURN std::[GlobalTypedef]new(<<scoper::GlobalTypedef #\>>(v));
	CASE :function:
		RETURN std::[GlobalFunction]new(<<scoper::GlobalFunction #\>>(v));
	CASE :variable:
		RETURN std::[GlobalVariable]new(<<scoper::GlobalVariable #\>>(v));
	CASE :class:
		RETURN std::[GlobalClass]new(<<scoper::GlobalClass #\>>(v));
	CASE :mask:
		RETURN std::[GlobalMask]new(<<scoper::GlobalMask #\>>(v));
	CASE :rawtype:
		RETURN std::[GlobalRawtype]new(<<scoper::GlobalRawtype #\>>(v));
	CASE :union:
		RETURN std::[GlobalUnion]new(<<scoper::GlobalUnion #\>>(v));
	CASE :enum:
		RETURN std::[GlobalEnum]new(<<scoper::GlobalEnum #\>>(v));
	CASE :externSymbol:
		RETURN std::[ExternSymbol]new(<<scoper::ExternSymbol #\>>(v));
	CASE :test:
		RETURN std::[Test]new(<<scoper::Test #\>>(v));
	}
}