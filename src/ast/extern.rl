INCLUDE 'std/optional'
INCLUDE "name.rl"

::rlc::ast [Stage:TYPE] ExternSymbol VIRTUAL
{
	LinkName: Stage::StringLiteral+ - std::Opt;

	{...};

	:transform{
		p: [Stage::Prev+] ExternSymbol #&,
		ctx: Stage::Context+ #&
	} {
		IF(p.LinkName)
			LinkName := :a(ctx.transform_string_literal(p.LinkName!));
	}
}