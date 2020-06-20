INCLUDE "scopeitem.rl"
INCLUDE "parser.rl"
INCLUDE "type.rl"
INCLUDE "../util/dynunion.rl"
INCLUDE "../src/file.rl"

::rlc::parser ExternSymbol -> Global, VIRTUAL ScopeItem
{
	Symbol: util::[parser::Type, GlobalFunction]DynUnion;
	Name: src::String;

	# FINAL name() src::String #& := Name;
	# FINAL type() Global::Type := Global::Type::externSymbol;

	parse(p: Parser &) bool
	{
		IF(!p.consume(tok::Type::extern))
			RETURN FALSE;


		IF(p.match_ahead(tok::Type::colon))
		{
			t: Trace(&p, "external variable");
			p.expect(tok::Type::identifier, &Name);
			p.expect(tok::Type::colon);

			Symbol := parser::Type::parse(p);
			IF(Symbol.is_empty())
				p.fail("expected type");
		} ELSE
		{
			t: Trace(&p, "external function");
			f: GlobalFunction;
			IF(!f.parse(p))
				p.fail("expected function");
			Symbol := ::std::dup(__cpp_std::move(f));
			Name := Symbol.second()->name();
		}

		RETURN TRUE;
	}
}