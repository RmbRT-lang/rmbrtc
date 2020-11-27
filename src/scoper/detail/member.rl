INCLUDE "../member.rl"
INCLUDE "../class.rl"
INCLUDE "../enum.rl"
INCLUDE "../variable.rl"
INCLUDE "../function.rl"
INCLUDE "../constructor.rl"
INCLUDE "../destructor.rl"
INCLUDE "../union.rl"
INCLUDE "../typedef.rl"


INCLUDE 'std/err/unimplemented'

::rlc::scoper::detail create_member(
	parsed: parser::Member #\,
	file: src::File #&,
	group: detail::ScopeItemGroup \) Member \
{
	SWITCH(type ::= parsed->type())
	{
	DEFAULT:
		THROW std::err::Unimplemented(type.NAME());
	CASE Member::Type::class:
		RETURN ::[MemberClass]new(<parser::MemberClass #\>(parsed), file, group);
	CASE Member::Type::enum:
		RETURN ::[MemberEnum]new(<parser::MemberEnum #\>(parsed), file, group);
	CASE Member::Type::enumConstant:
		RETURN ::[Enum::Constant]new(<parser::Enum::Constant #\>(parsed), file, group);
	CASE Member::Type::variable:
		RETURN ::[MemberVariable]new(<parser::MemberVariable #\>(parsed), file, group);
	CASE Member::Type::function:
		RETURN ::[MemberFunction]new(<parser::MemberFunction #\>(parsed), file, group);
	CASE Member::Type::constructor:
		RETURN ::[Constructor]new(<parser::Constructor #\>(parsed), file, group);
	CASE Member::Type::destructor:
		RETURN ::[Destructor]new(<parser::Destructor #\>(parsed), file, group);
	CASE Member::Type::union:
		RETURN ::[MemberUnion]new(<parser::MemberUnion #\>(parsed), file, group);
	CASE Member::Type::typedef:
		RETURN ::[MemberTypedef]new(<parser::MemberTypedef #\>(parsed), file, group);
	}
}