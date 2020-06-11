INCLUDE "parser.rl"
INCLUDE "scopeitem.rl"
(/INCLUDE "namespace.rl"
INCLUDE "typedef.rl"
INCLUDE "variable.rl"
INCLUDE "function.rl"/)

::rlc::parser Global -> VIRTUAL ScopeItem
{
	ENUM Type
	{
		namespace,
		typedef,
		function,
		variable,
		class
	}
	# ABSTRACT type() Global::Type;
	# FINAL category() ScopeItem::Category := ScopeItem::Category::global;

	STATIC parse(p: Parser &) Global *
	{
		{
			v: Namespace;
			IF(v.parse(p))
				RETURN ::[TYPE(v)]new(__cpp_std::move(v));
		}
		{
			v: GlobalTypedef;
			IF(v.parse(p))
				RETURN ::[TYPE(v)]new(__cpp_std::move(v));
		}
		{
			v: GlobalVariable;
			IF(v.parse_var_decl(p))
			{
				p.expect(tok::Type::semicolon);
				RETURN ::[TYPE(v)]new(__cpp_std::move(v));
			}
		}
		{
			v: GlobalFunction;
			IF(v.parse(p))
				RETURN ::[TYPE(v)]new(__cpp_std::move(v));
		}

		RETURN NULL;
	}
}