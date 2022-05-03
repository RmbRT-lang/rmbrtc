INCLUDE 'std/range'

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
		= :a(:identifier(tok->Content));
	ELSE
	{
		FOR(it ::= std::range::start(specials); it; ++it)
			IF(p.consume(it->(0)))
				= :a(:special(it->(1)));
		p.fail("expected <, >, <>, !, ?, or <-"); DIE;
	}
}