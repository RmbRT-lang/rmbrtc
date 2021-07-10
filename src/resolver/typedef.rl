INCLUDE "../scoper/typedef.rl"
INCLUDE "type.rl"
INCLUDE "global.rl"
INCLUDE "member.rl"

::rlc::resolver Typedef VIRTUAL -> ScopeItem
{
	# FINAL type() ScopeItem::Type := :typedef;

	Type: resolver::Type - std::Dynamic;

	{v: scoper::Typedef #\, cache: Cache &}
	->	ScopeItem(v, cache)
	:	Type(:gc, resolver::Type::create(v->parent_scope(), v->Type));
}

::rlc::resolver GlobalTypedef -> Global, Typedef
{
	{v: scoper::GlobalTypedef #\, cache: Cache &}
	->	Typedef(v, cache);
}

::rlc::resolver MemberTypedef -> Member, Typedef
{
	{v: scoper::MemberTypedef #\, cache: Cache &}
	->	Member(v),
		Typedef(v, cache);
}