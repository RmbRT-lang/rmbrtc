INCLUDE 'std/optional'
INCLUDE "name.rl"

::rlc::ast [Stage:TYPE] ExternSymbol VIRTUAL
{
	LinkName: Stage-String - std::Opt;
}