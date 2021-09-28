INCLUDE "../scoper/enum.rl"
INCLUDE "member.rl"
INCLUDE "global.rl"
INCLUDE "scopeitem.rl"

::rlc::resolver Enum VIRTUAL -> ScopeItem
{
	Constant -> ScopeItem, Member
	{
		Value: src::Index;
		Type: Enum #\;

		{
			constant: scoper::Enum::Constant #\,
			enum: Enum #\,
			cache: Cache &
		}->	ScopeItem(constant, cache),
			Member(constant)
		:	Type(enum),
			Value(constant->Value);
	}

	Constants: Constant - std::DynVector;
	Size: src::Size;

	{enum: scoper::Enum #\, cache: Cache &}
	->	ScopeItem(enum, cache)
	:	Size(enum->Size)
	{
		FOR(constant ::= enum->Constants.start(); constant; ++constant)
			Constants += :create(constant!, &THIS, cache);
	}
}

::rlc::resolver GlobalEnum -> Global, Enum
{
	{enum: scoper::GlobalEnum #\, cache: Cache &}
	->	Enum(enum, cache);
}

::rlc::resolver MemberEnum -> Member, Enum
{
	{enum: scoper::MemberEnum #\, cache: Cache &}
	->	Member(enum),
		Enum(enum, cache);
}