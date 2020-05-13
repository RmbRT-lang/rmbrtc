INCLUDE "parser.rl"
(/INCLUDE "namespace.rl"
INCLUDE "typedef.rl"
INCLUDE "variable.rl"
INCLUDE "function.rl"/)

::rlc::parser ENUM ScopeEntryType
{
	namespace,
	typedef,
	function,
	variable
}

::rlc::parser ScopeEntry
{
	Name: src::String;

	# ABSTRACT type() ScopeEntryType;

	STATIC parse(p: Parser &) ScopeEntry *
	{
		{
			v: Namespace;
			IF(v.parse(p))
				RETURN ::[TYPE(v)]new(__cpp_std::move(v));
		}
		{
			v: Typedef;
			IF(v.parse(p))
				RETURN ::[TYPE(v)]new(__cpp_std::move(v));
		}
		{
			v: Variable;
			IF(v.parse(p, TRUE, TRUE, TRUE))
			{
				p.expect(tok::Type::semicolon);
				RETURN ::[TYPE(v)]new(__cpp_std::move(v));
			}
		}
		{
			v: Function;
			IF(v.parse(p, TRUE))
				RETURN ::[TYPE(v)]new(__cpp_std::move(v));
		}

		RETURN NULL;
	}
}