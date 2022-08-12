(//
	Caches the converted objects from a previous compiler stage.
	Destroy the cache if you want to prune unused objects.
/)
::rlc::ast [Stage: TYPE; T: TYPE]Cache
{
	References: std::[T::Prev+ #\; T - std::Shared]NatMap;

	THIS[p: T::Prev+ #\, file: Stage::PrevFile+ #&] T - std::Shared
	{
		IF(entry ::= References.find(p))
			= *entry;
		ELSE
		{
			new ::= <<<T>>>(p, file, THIS);
			References.insert(p, new);
			= new;
		}
	}
}