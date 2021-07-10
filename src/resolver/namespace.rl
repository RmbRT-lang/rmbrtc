INCLUDE "../scoper/namespace.rl"
INCLUDE "global.rl"

::rlc::resolver Namespace -> ScopeItem, Global
{
	# FINAL type() ScopeItem::Type := :namespace;

	Entries: Global - std::Dynamic - std::Vector;

	{v: scoper::Namespace #\, cache: Cache &}->
		ScopeItem(v, cache)
	{
		FOR(group ::= v->Items.start(); group; ++group)
			FOR(it ::= (*group)->Items.start(); it; ++it)
				Entries += :gc(Global::create(<<scoper::Global #\>>(&**it), cache));
	}
}