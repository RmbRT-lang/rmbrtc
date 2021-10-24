INCLUDE "../global.rl"
INCLUDE "../namespace.rl"
INCLUDE "../class.rl"
INCLUDE "../mask.rl"
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
	file: parser::File#&,
	group:  detail::ScopeItemGroup \
) Global \
{
	TYPE SWITCH(global)
	{
	DEFAULT:
		THROW <std::err::Unimplemented>(TYPE(global));
	parser::Namespace:
		RETURN std::[Namespace]new(<parser::Namespace #\>(global), file, group);
	parser::GlobalClass:
		RETURN std::[GlobalClass]new(<parser::GlobalClass #\>(global), file, group);
	parser::GlobalEnum:
		RETURN std::[GlobalEnum]new(<parser::GlobalEnum #\>(global), file, group);
	parser::GlobalFunction:
		RETURN std::[GlobalFunction]new(<parser::GlobalFunction #\>(global), file, group);
	parser::GlobalVariable:
		RETURN std::[GlobalVariable]new(<parser::GlobalVariable #\>(global), file, group);
	parser::ExternSymbol:
		RETURN std::[ExternSymbol]new(<parser::ExternSymbol #\>(global), file, group);
	parser::GlobalRawtype:
		RETURN std::[GlobalRawtype]new(<parser::GlobalRawtype #\>(global), file, group);
	parser::GlobalTypedef:
		RETURN std::[GlobalTypedef]new(<parser::GlobalTypedef #\>(global), file, group);
	parser::GlobalUnion:
		RETURN std::[GlobalUnion]new(<parser::GlobalUnion #\>(global), file, group);
	parser::GlobalMask:
		RETURN std::[GlobalMask]new(<parser::GlobalMask #\>(global), file, group);
	}
}