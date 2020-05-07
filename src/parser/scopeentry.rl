INCLUDE "parser.rl"

::rlc::parser ScopeEntry
{
	Name: src::String;

	STATIC parse(p: Parser &) ScopeEntry *
	{
		{
			v ::= [Namespace]new();
			IF(v->parse(p))
				RETURN v;
			ELSE
				delete(v);
		}

		RETURN NULL;
	}
}