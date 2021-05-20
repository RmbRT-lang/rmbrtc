INCLUDE "scopeitem.rl"
INCLUDE "parser.rl"
INCLUDE "type.rl"
INCLUDE "../util/dynunion.rl"
INCLUDE "../src/file.rl"

::rlc::parser ExternSymbol -> Global, VIRTUAL ScopeItem
{
	Symbol: util::[parser::GlobalVariable; GlobalFunction]DynUnion;

	# FINAL name() src::String #& := is_variable()
		? variable()->name()
		: function()->name();
	# FINAL type() Global::Type := :externSymbol;
	# FINAL overloadable() bool := FALSE;

	# is_variable() INLINE bool := Symbol.is_first();
	# variable() INLINE GlobalVariable \ := Symbol.first();
	# is_function() INLINE bool := Symbol.is_second();
	# function() INLINE GlobalFunction \ := Symbol.second();

	parse(p: Parser &) bool
	{
		IF(!p.consume(:extern))
			RETURN FALSE;

		t: Trace(&p, "external symbol");
		IF(p.match_ahead(:colon))
		{
			var: std::[GlobalVariable]Dynamic := :gc([GlobalVariable]new());
			IF(!var->parse_extern(p))
				p.fail("expected variable");
			Symbol := var.release();
		} ELSE
		{
			f: std::[GlobalFunction]Dynamic := :gc([GlobalFunction]new());
			IF(!f->parse_extern(p))
				p.fail("expected function");
			Symbol := f.release();
		}

		RETURN TRUE;
	}
}