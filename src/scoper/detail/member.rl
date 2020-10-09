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
	type ::= parsed->type();

	IF(type == Member::Type::class)
		RETURN ::[MemberClass]new(<parser::MemberClass #\>(parsed), file, group);
	IF(type == Member::Type::enum)
		RETURN ::[MemberEnum]new(<parser::MemberEnum #\>(parsed), file, group);
	IF(type == Member::Type::enumConstant)
		RETURN ::[Enum::Constant]new(<parser::Enum::Constant #\>(parsed), file, group);
	IF(type == Member::Type::variable)
		RETURN ::[MemberVariable]new(<parser::MemberVariable #\>(parsed), file, group);
	IF(type == Member::Type::function)
		RETURN ::[MemberFunction]new(<parser::MemberFunction #\>(parsed), file, group);
	IF(type == Member::Type::constructor)
		RETURN ::[Constructor]new(<parser::Constructor #\>(parsed), file, group);
	IF(type == Member::Type::destructor)
		RETURN ::[Destructor]new(<parser::Destructor #\>(parsed), file, group);
	IF(type == Member::Type::union)
		RETURN ::[MemberUnion]new(<parser::MemberUnion #\>(parsed), file, group);
	IF(type == Member::Type::typedef)
		RETURN ::[MemberTypedef]new(<parser::MemberTypedef #\>(parsed), file, group);

	THROW std::err::Unimplemented(type.NAME());
}