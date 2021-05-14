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
		RETURN ::[MemberClass]new(<parser::MemberClass #\>(parsed), file, group);
	CASE :enum:
		RETURN ::[MemberEnum]new(<parser::MemberEnum #\>(parsed), file, group);
	CASE :enumConstant:
		RETURN ::[Enum::Constant]new(<parser::Enum::Constant #\>(parsed), file, group);
	CASE :variable:
		RETURN ::[MemberVariable]new(<parser::MemberVariable #\>(parsed), file, group);
	CASE :function:
		RETURN ::[MemberFunction]new(<parser::MemberFunction #\>(parsed), file, group);
	CASE :rawtype:
		RETURN ::[MemberRawtype]new(<parser::MemberRawtype #\>(parsed), file, group);
	CASE :constructor:
		RETURN ::[Constructor]new(<parser::Constructor #\>(parsed), file, group);
	CASE :destructor:
		RETURN ::[Destructor]new(<parser::Destructor #\>(parsed), file, group);
	CASE :union:
		RETURN ::[MemberUnion]new(<parser::MemberUnion #\>(parsed), file, group);
	CASE :typedef:
		RETURN ::[MemberTypedef]new(<parser::MemberTypedef #\>(parsed), file, group);
	}
}