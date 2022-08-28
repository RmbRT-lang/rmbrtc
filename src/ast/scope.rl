::rlc::ast [Name: TYPE; Elem: TYPE] Scope
{
	// This scope's elements coming from this file only.
	Elements: std::[Name; Elem]AutoMap;
	// All (transitively) included scopes coming only from other files.
	IncludedScopes: THIS \ - std::NatSet;

	THIS[n: Name#&] Elem *
	{
		IF(e ::= Elements.find(n))
			= e;
		FOR(scope ::= IncludedScopes.start())
			IF(e ::= scope!->Elements.find(n))
				= e;
		= NULL;
	}

	merge_locally(rhs: THIS &&) VOID
	{
		ASSERT(!##IncludedScopes);
		ASSERT(!##rhs.IncludedScopes);

		FOR(kv ::= rhs.IncludedScopes.start())
		{
			IF(existing ::= IncludedScopes.find(kv!.(0)))
			{
				IF:!(merge_lhs ::= <<Mergeable *>>(existing))
					THROW :cannotMerge(existing, rhs);
			}
		}
	}

	insert(n: Name) VOID;
}