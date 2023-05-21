(//
	Caches the converted objects from a previous compiler stage.
	Destroy the cache if you want to prune unused objects.
/)
::rlc::ast [Stage: TYPE; T: TYPE]Cache
{
	References: std::[T::Prev+ #\; T - std::Val]Map;

	THIS[p: T::Prev+ #\, ctx: Stage::Context+] T - std::Val
	{
		IF(entry ::= References.find(p))
			= *entry;
		ELSE
		{
			new: T-std::Val := :make(*p, ctx);
			References.insert(p, new);
			= &&new;
		}
	}
}