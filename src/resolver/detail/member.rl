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
	scoper::MemberTypedef:
		RETURN std::[MemberTypedef]new(<<scoper::MemberTypedef #\>>(member), cache);
	scoper::MemberFunction:
		RETURN std::[MemberFunction]new(<<scoper::MemberFunction#\>>(member), cache);
	scoper::MemberVariable:
		RETURN std::[MemberVariable]new(<<scoper::MemberVariable#\>>(member), cache);
	scoper::MemberClass:
		RETURN std::[MemberClass]new(<<scoper::MemberClass#\>>(member), cache);
	scoper::MemberRawtype:
		RETURN std::[MemberRawtype]new(<<scoper::MemberRawtype#\>>(member), cache);
	scoper::MemberUnion:
		RETURN std::[MemberUnion]new(<<scoper::MemberUnion#\>>(member), cache);
	scoper::MemberEnum:
		RETURN std::[MemberEnum]new(<<scoper::MemberEnum#\>>(member), cache);
	scoper::Constructor:
		RETURN std::[Constructor]new(<<scoper::Constructor#\>>(member), cache);
	scoper::Destructor:
		RETURN std::[Destructor]new(<<scoper::Destructor#\>>(member), cache);
	}
}
