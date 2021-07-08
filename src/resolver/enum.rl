INCLUDE "../scoper/enum.rl"
INCLUDE "member.rl"
INCLUDE "global.rl"
INCLUDE "scopeitem.rl"

::rlc::resolver Enum VIRTUAL -> ScopeItem
{
	# FINAL type() ScopeItem::Type := :enum;

	Constant -> ScopeItem, Member
	{
		# FINAL type() ScopeItem::Type := :enumConstant;

		Value: src::Index;
		Type: Enum #\;

		{
			constant: scoper::Enum::Constant #&,
			enum: Enum #\
		}:	ScopeItem(&constant),
			Member(&constant),
			Type(enum),
			Value(constant.Value);
	}

	Constants: Constant - std::Vector;
	Size: src::Size;

	{enum: scoper::Enum #\}:
		ScopeItem(enum),
		Size(enum->Size)
	{
		FOR(constant ::= enum->Constants.start(); constant; ++constant)
			Constants += (**constant, &THIS);
	}
}

::rlc::resolver GlobalEnum -> Global, Enum
{

	{enum: scoper::GlobalEnum #\}:
		Enum(enum);
}

::rlc::resolver MemberEnum -> Member, Enum
{
	{enum: scoper::MemberEnum #\}:
		Member(enum),
		Enum(enum);
}