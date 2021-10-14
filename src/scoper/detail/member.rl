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
	TYPE SWITCH(parsed)
	{
	DEFAULT:
		THROW <std::err::Unimplemented>(TYPE(parsed));
	parser::MemberClass:
		RETURN std::[MemberClass]new(<parser::MemberClass #\>(parsed), file, group);
	parser::MemberEnum:
		RETURN std::[MemberEnum]new(<parser::MemberEnum #\>(parsed), file, group);
	parser::Enum::Constant:
		RETURN std::[Enum::Constant]new(<parser::Enum::Constant #\>(parsed), file, group);
	parser::MemberVariable:
		RETURN std::[MemberVariable]new(<parser::MemberVariable #\>(parsed), file, group);
	parser::MemberFunction:
		RETURN std::[MemberFunction]new(<parser::MemberFunction #\>(parsed), file, group);
	parser::MemberRawtype:
		RETURN std::[MemberRawtype]new(<parser::MemberRawtype #\>(parsed), file, group);
	parser::Constructor:
		RETURN std::[Constructor]new(<parser::Constructor #\>(parsed), file, group);
	parser::Destructor:
		RETURN std::[Destructor]new(<parser::Destructor #\>(parsed), file, group);
	parser::MemberUnion:
		RETURN std::[MemberUnion]new(<parser::MemberUnion #\>(parsed), file, group);
	parser::MemberTypedef:
		RETURN std::[MemberTypedef]new(<parser::MemberTypedef #\>(parsed), file, group);
	}
}