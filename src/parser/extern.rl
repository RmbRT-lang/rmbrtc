INCLUDE "scopeitem.rl"
INCLUDE "parser.rl"
INCLUDE "type.rl"
INCLUDE "../util/dynunion.rl"
INCLUDE "../src/file.rl"

::rlc::parser ExternSymbol -> Global, VIRTUAL ScopeItem
{
	Symbol: util::[parser::GlobalVariable, GlobalFunction]DynUnion;

	# FINAL name() src::String #& := is_variable()
		? variable()->name()
		: function()->name();
	# FINAL type() Global::Type := Global::Type::externSymbol;

	# is_variable() INLINE bool := Symbol.is_first();
	# variable() INLINE GlobalVariable \ := Symbol.first();
	# is_function() INLINE bool := Symbol.is_second();
	# function() INLINE GlobalFunction \ := Symbol.second();

	parse(p: Parser &) bool
	{
		IF(!p.consume(tok::Type::extern))
			RETURN FALSE;

		t: Trace(&p, "external symbol");
		IF(p.match_ahead(tok::Type::colon))
		{
			var: std::[GlobalVariable]Dynamic := [GlobalVariable]new();
			IF(!var->parse_extern(p))
				p.fail("expected variable");
			Symbol := var.release();
		} ELSE
		{
			f: std::[GlobalFunction]Dynamic := [GlobalFunction]new();
			IF(!f->parse_extern(p))
				p.fail("expected function");
			Symbol := f.release();
		}

		RETURN TRUE;
	}
}