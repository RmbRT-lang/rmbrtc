(//
	Caches the converted objects from a previous compiler stage.
	Destroy the cache if you want to prune unused objects.
/)
::rlc::ast [Stage: TYPE; T: TYPE]Cache
{
	References: std::[T::Prev+ #\; T - std::Shared]Map;

	THIS[p: T::Prev+ #\, f: Stage::PrevFile+, s: Stage &, parent: [Stage]ScopeBase \] T - std::Shared
	{
		IF(entry ::= References.find(p))
			= *entry;
		ELSE
		{
			new: T-std::Shared := :make(*p, f, s, parent);
			References.insert(p, new);
			= &&new;
		}
	}
}