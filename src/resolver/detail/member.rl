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
	member: scoper::Member #\
) Member \
{
	SWITCH(t ::= <<scoper::ScopeItem #\>>(member)->type())
	{
	DEFAULT:
		THROW <std::err::Unimplemented>(t.NAME());
	CASE :typedef:
		RETURN std::[MemberTypedef]new(<<scoper::MemberTypedef #\>>(member));
	CASE :function:
		RETURN std::[MemberFunction]new(<<scoper::MemberFunction#\>>(member));
	CASE :variable:
		RETURN std::[MemberVariable]new(<<scoper::MemberVariable#\>>(member));
	CASE :class:
		RETURN std::[MemberClass]new(<<scoper::MemberClass#\>>(member));
	CASE :rawtype:
		RETURN std::[MemberRawtype]new(<<scoper::MemberRawtype#\>>(member));
	CASE :union:
		RETURN std::[MemberUnion]new(<<scoper::MemberUnion#\>>(member));
	CASE :enum:
		RETURN std::[MemberEnum]new(<<scoper::MemberEnum#\>>(member));
	CASE :constructor:
		RETURN std::[Constructor]new(<<scoper::Constructor#\>>(member));
	CASE :destructor:
		RETURN std::[Destructor]new(<<scoper::Destructor#\>>(member));
	}
}
