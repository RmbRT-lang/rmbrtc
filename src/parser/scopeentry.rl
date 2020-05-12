INCLUDE "parser.rl"

::rlc::parser ENUM ScopeEntryType
{
	namespace,
	typedef
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

		RETURN NULL;
	}
}