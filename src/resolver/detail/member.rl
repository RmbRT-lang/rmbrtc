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
	SWITCH(t ::= <<scoper::ScopeItem #\>>(member)->type())
	{
	DEFAULT:
		THROW <std::err::Unimplemented>(t.NAME());
	CASE :typedef:
		RETURN std::[MemberTypedef]new(<<scoper::MemberTypedef #\>>(member), cache);
	CASE :function:
		RETURN std::[MemberFunction]new(<<scoper::MemberFunction#\>>(member), cache);
	CASE :variable:
		RETURN std::[MemberVariable]new(<<scoper::MemberVariable#\>>(member), cache);
	CASE :class:
		RETURN std::[MemberClass]new(<<scoper::MemberClass#\>>(member), cache);
	CASE :rawtype:
		RETURN std::[MemberRawtype]new(<<scoper::MemberRawtype#\>>(member), cache);
	CASE :union:
		RETURN std::[MemberUnion]new(<<scoper::MemberUnion#\>>(member), cache);
	CASE :enum:
		RETURN std::[MemberEnum]new(<<scoper::MemberEnum#\>>(member), cache);
	CASE :constructor:
		RETURN std::[Constructor]new(<<scoper::Constructor#\>>(member), cache);
	CASE :destructor:
		RETURN std::[Destructor]new(<<scoper::Destructor#\>>(member), cache);
	}
}
