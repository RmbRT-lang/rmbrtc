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
		THROW std::err::Unimplemented(type.NAME());
	CASE :namespace:
		RETURN ::[Namespace]new(<parser::Namespace #\>(global), file, group);
	CASE :class:
		RETURN ::[GlobalClass]new(<parser::GlobalClass #\>(global), file, group);
	CASE :enum:
		RETURN ::[GlobalEnum]new(<parser::GlobalEnum #\>(global), file, group);
	CASE :function:
		RETURN ::[GlobalFunction]new(<parser::GlobalFunction #\>(global), file, group);
	CASE :variable:
		RETURN ::[GlobalVariable]new(<parser::GlobalVariable #\>(global), file, group);
	CASE :externSymbol:
		RETURN ::[ExternSymbol]new(<parser::ExternSymbol #\>(global), file, group);
	CASE :typedef:
		RETURN ::[GlobalTypedef]new(<parser::GlobalTypedef #\>(global), file, group);
	CASE :union:
		RETURN ::[GlobalUnion]new(<parser::GlobalUnion #\>(global), file, group);
	CASE :concept:
		RETURN ::[GlobalConcept]new(<parser::GlobalConcept #\>(global), file, group);
	}
}