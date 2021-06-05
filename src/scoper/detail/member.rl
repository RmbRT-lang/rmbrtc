INCLUDE "../member.rl"
INCLUDE "../class.rl"
INCLUDE "../enum.rl"
INCLUDE "../variable.rl"
INCLUDE "../function.rl"
INCLUDE "../constructor.rl"
INCLUDE "../destructor.rl"
INCLUDE "../union.rl"
INCLUDE "../typedef.rl"
INCLUDE "../rawtype.rl"


INCLUDE 'std/err/unimplemented'

::rlc::scoper::detail create_member(
	parsed: parser::Member #\,
	file: src::File #&,
	group: detail::ScopeItemGroup \) Member \
{
	SWITCH(type ::= parsed->type())
	{
	DEFAULT:
		THROW <std::err::Unimplemented>(type.NAME());
	CASE :class:
		RETURN std::[MemberClass]new(<parser::MemberClass #\>(parsed), file, group);
	CASE :enum:
		RETURN std::[MemberEnum]new(<parser::MemberEnum #\>(parsed), file, group);
	CASE :enumConstant:
		RETURN std::[Enum::Constant]new(<parser::Enum::Constant #\>(parsed), file, group);
	CASE :variable:
		RETURN std::[MemberVariable]new(<parser::MemberVariable #\>(parsed), file, group);
	CASE :function:
		RETURN std::[MemberFunction]new(<parser::MemberFunction #\>(parsed), file, group);
	CASE :rawtype:
		RETURN std::[MemberRawtype]new(<parser::MemberRawtype #\>(parsed), file, group);
	CASE :constructor:
		RETURN std::[Constructor]new(<parser::Constructor #\>(parsed), file, group);
	CASE :destructor:
		RETURN std::[Destructor]new(<parser::Destructor #\>(parsed), file, group);
	CASE :union:
		RETURN std::[MemberUnion]new(<parser::MemberUnion #\>(parsed), file, group);
	CASE :typedef:
		RETURN std::[MemberTypedef]new(<parser::MemberTypedef #\>(parsed), file, group);
	}
}