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
	CASE Global::Type::namespace:
		RETURN ::[Namespace]new(<parser::Namespace #\>(global), file, group);
	CASE Global::Type::class:
		RETURN ::[GlobalClass]new(<parser::GlobalClass #\>(global), file, group);
	CASE Global::Type::enum:
		RETURN ::[GlobalEnum]new(<parser::GlobalEnum #\>(global), file, group);
	CASE Global::Type::function:
		RETURN ::[GlobalFunction]new(<parser::GlobalFunction #\>(global), file, group);
	CASE Global::Type::variable:
		RETURN ::[GlobalVariable]new(<parser::GlobalVariable #\>(global), file, group);
	CASE Global::Type::externSymbol:
		RETURN ::[ExternSymbol]new(<parser::ExternSymbol #\>(global), file, group);
	CASE Global::Type::typedef:
		RETURN ::[GlobalTypedef]new(<parser::GlobalTypedef #\>(global), file, group);
	CASE Global::Type::union:
		RETURN ::[GlobalUnion]new(<parser::GlobalUnion #\>(global), file, group);
	CASE Global::Type::concept:
		RETURN ::[GlobalConcept]new(<parser::GlobalConcept #\>(global), file, group);
	}
}