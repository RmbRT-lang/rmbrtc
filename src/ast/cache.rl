(//
	Caches the converted objects from a previous compiler stage.
	Destroy the cache if you want to prune unused objects.
/)
::rlc::ast [Stage: TYPE; T: TYPE]Cache
{
	[U:TYPE] PRIVATE TYPE Prev := U::Prev;
	References: std::[T-Prev #\; T - std::Shared]NatMap;

	PRIVATE TYPE PrevFile := Stage::PrevFile!;
	THIS[p: T-Prev #\, file: PrevFile] T - std::Shared
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