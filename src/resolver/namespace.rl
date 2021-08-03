INCLUDE "../scoper/namespace.rl"
INCLUDE "global.rl"

::rlc::resolver Namespace -> ScopeItem, Global
{
	# FINAL type() ScopeItem::Type := :namespace;

	Entries: Global - std::DynVector;

	{v: scoper::Namespace #\, cache: Cache &}->
		ScopeItem(v, cache)
	{
		FOR(group ::= v->Items.start(); group; ++group)
			FOR(it ::= (*group)->Items.start(); it; ++it)
				Entries += :gc(<<<Global>>>(<<scoper::Global #\>>(&**it), cache));
	}
}