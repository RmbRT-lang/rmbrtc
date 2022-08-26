INCLUDE 'std/optional'
INCLUDE "name.rl"

::rlc::ast [Stage:TYPE] ExternSymbol VIRTUAL
{
	LinkName: Stage::StringLiteral+ - std::Opt;

	{...};

	:transform{
		p: [Stage::Prev+] ExternSymbol #&,
		f: Stage::PrevFile+,
		s: Stage &
	} {
		IF(p.LinkName)
			LinkName := :a(s.transform_string(p.LinkName!, f));
	}
}