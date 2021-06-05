INCLUDE "../global.rl"
INCLUDE "../namespace.rl"
INCLUDE "../class.rl"
INCLUDE "../concept.rl"
INCLUDE "../enum.rl"
INCLUDE "../function.rl"
INCLUDE "../variable.rl"
INCLUDE "../extern.rl"
INCLUDE "../union.rl"
INCLUDE "../typedef.rl"
INCLUDE "../rawtype.rl"

INCLUDE 'std/err/unimplemented'

::rlc::scoper::detail create_global(
	global: parser::Global #\,
	file: src::File#&,
	group:  detail::ScopeItemGroup \
) Global \
{
	SWITCH(type ::= global->type())
	{
	DEFAULT:
		THROW <std::err::Unimplemented>(type.NAME());
	CASE :namespace:
		RETURN std::[Namespace]new(<parser::Namespace #\>(global), file, group);
	CASE :class:
		RETURN std::[GlobalClass]new(<parser::GlobalClass #\>(global), file, group);
	CASE :enum:
		RETURN std::[GlobalEnum]new(<parser::GlobalEnum #\>(global), file, group);
	CASE :function:
		RETURN std::[GlobalFunction]new(<parser::GlobalFunction #\>(global), file, group);
	CASE :variable:
		RETURN std::[GlobalVariable]new(<parser::GlobalVariable #\>(global), file, group);
	CASE :externSymbol:
		RETURN std::[ExternSymbol]new(<parser::ExternSymbol #\>(global), file, group);
	CASE :rawtype:
		RETURN std::[GlobalRawtype]new(<parser::GlobalRawtype #\>(global), file, group);
	CASE :typedef:
		RETURN std::[GlobalTypedef]new(<parser::GlobalTypedef #\>(global), file, group);
	CASE :union:
		RETURN std::[GlobalUnion]new(<parser::GlobalUnion #\>(global), file, group);
	CASE :concept:
		RETURN std::[GlobalConcept]new(<parser::GlobalConcept #\>(global), file, group);
	}
}