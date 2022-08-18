(//
	Caches the converted objects from a previous compiler stage.
	Destroy the cache if you want to prune unused objects.
/)
::rlc::ast [Stage: TYPE; T: TYPE]Cache
{
	References: std::[T::Prev+ #\; T - std::Shared]NatMap;

	THIS[p: T::Prev+ #\, f: Stage::PrevFile+, s: Stage &] T - std::Shared
	{
		IF(entry ::= References.find(p))
			= *entry;
		ELSE
		{
			new ::= <<<T>>>(p, f, s);
			References.insert(p, new);
			= new;
		}
	}
}