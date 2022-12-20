INCLUDE 'std/range'
INCLUDE "../ast/symbolconstant.rl"
INCLUDE "type.rl"

::rlc::parser::symbol_constant parse(
	p: Parser &
) ast::[Config]SymbolConstant - std::Opt
{
	STATIC specials: {tok::Type, ast::[Config]SymbolConstant::Type}#[](
		(:less, :less),
		(:greater, :greater),
		(:lessGreater, :lessGreater),
		(:exclamationMark, :exclamationMark),
		(:questionMark, :exclamationMark),
		(:lessMinus, :lessMinus));

	IF(!p.consume(:colon))
		= NULL;

	IF(tok ::= p.consume(:identifier))
		IF(p.consume(:dot))
			= :a(:typed_identifier(tok->Content, type::parse_x(p)));
		ELSE
			= :a(:identifier(tok->Content));
	ELSE
	{
		FOR(it ::= std::range::start(specials!); it; ++it)
			IF(p.consume(it->(0)))
				IF(p.consume(:dot))
					= :a(:typed_special(it->(1), type::parse_x(p)));
				ELSE
					= :a(:special(it->(1)));
		p.fail("expected <, >, <>, !, ?, or <-"); DIE;
	}
}