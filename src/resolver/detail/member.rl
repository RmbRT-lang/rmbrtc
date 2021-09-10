INCLUDE "../../scoper/member.rl"
INCLUDE "../member.rl"
INCLUDE "../typedef.rl"
INCLUDE "../function.rl"
INCLUDE "../variable.rl"
INCLUDE "../class.rl"
INCLUDE "../rawtype.rl"
INCLUDE "../union.rl"
INCLUDE "../enum.rl"
INCLUDE "../constructor.rl"
INCLUDE "../destructor.rl"

::rlc::resolver::detail create_member(
	member: scoper::Member #\,
	cache: Cache &
) Member \
{
	TYPE SWITCH(member)
	{
	DEFAULT:
		THROW <std::err::Unimplemented>(TYPE(member));
	CASE scoper::MemberTypedef:
		RETURN std::[MemberTypedef]new(<<scoper::MemberTypedef #\>>(member), cache);
	CASE scoper::MemberFunction:
		RETURN std::[MemberFunction]new(<<scoper::MemberFunction#\>>(member), cache);
	CASE scoper::MemberVariable:
		RETURN std::[MemberVariable]new(<<scoper::MemberVariable#\>>(member), cache);
	CASE scoper::MemberClass:
		RETURN std::[MemberClass]new(<<scoper::MemberClass#\>>(member), cache);
	CASE scoper::MemberRawtype:
		RETURN std::[MemberRawtype]new(<<scoper::MemberRawtype#\>>(member), cache);
	CASE scoper::MemberUnion:
		RETURN std::[MemberUnion]new(<<scoper::MemberUnion#\>>(member), cache);
	CASE scoper::MemberEnum:
		RETURN std::[MemberEnum]new(<<scoper::MemberEnum#\>>(member), cache);
	CASE scoper::Constructor:
		RETURN std::[Constructor]new(<<scoper::Constructor#\>>(member), cache);
	CASE scoper::Destructor:
		RETURN std::[Destructor]new(<<scoper::Destructor#\>>(member), cache);
	}
}
