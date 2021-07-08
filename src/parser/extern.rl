INCLUDE "scopeitem.rl"
INCLUDE "parser.rl"
INCLUDE "type.rl"
INCLUDE "../util/dynunion.rl"
INCLUDE "../src/file.rl"

::rlc::parser ExternSymbol -> Global, ScopeItem
{
	Symbol: util::[parser::GlobalVariable; GlobalFunction]DynUnion;

	# FINAL name() src::String #& := is_variable()
		? variable()->name()
		: function()->name();
	# FINAL type() ScopeItem::Type := :externSymbol;
	# FINAL overloadable() BOOL := FALSE;

	# is_variable() INLINE BOOL := Symbol.is_first();
	# variable() INLINE GlobalVariable \ := Symbol.first();
	# is_function() INLINE BOOL := Symbol.is_second();
	# function() INLINE GlobalFunction \ := Symbol.second();

	parse(p: Parser &) BOOL
	{
		IF(!p.consume(:extern))
			RETURN FALSE;

		t: Trace(&p, "external symbol");
		IF(p.match_ahead(:colon))
		{
			var: GlobalVariable;
			IF(!var.parse_extern(p))
				p.fail("expected variable");
			Symbol := :gc(std::dup(&&var));
		} ELSE
		{
			f: GlobalFunction;
			IF(!f.parse_extern(p))
				p.fail("expected function");
			Symbol := :gc(std::dup(&&f));
		}

		RETURN TRUE;
	}
}