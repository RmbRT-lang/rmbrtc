INCLUDE "../parser/rawtype.rl"
INCLUDE "expression.rl"
INCLUDE "scopeitem.rl"
INCLUDE "member.rl"
INCLUDE "scope.rl"

INCLUDE 'std/memory'

::rlc::scoper Rawtype -> VIRTUAL ScopeItem, Scope
{
	Size: Expression - std::Dynamic;

	{
		parsed: parser::Rawtype #\,
		file: src::File #&,
		group: detail::ScopeItemGroup \
	}:	Scope(&THIS, group->Scope),
		Size(:gc(Expression::create(parsed->Size, file)))
	{
		FOR(i ::= 0; i < parsed->Members.size(); i++)
			insert(parsed->Members[i], file);
	}
}

::rlc::scoper GlobalRawtype -> Global, Rawtype
{
	# FINAL type() Global::Type := :rawtype;

	{
		parsed: parser::GlobalRawtype #\,
		file: src::File #&,
		group: detail::ScopeItemGroup \
	}:	ScopeItem(group, parsed, file),
		Rawtype(parsed, file, group);
}

::rlc::scoper MemberRawtype -> Member, Rawtype
{
	# FINAL type() Member::Type := :rawtype;

	{
		parsed: parser::MemberRawtype #\,
		file: src::File #&,
		group: detail::ScopeItemGroup \
	}:	ScopeItem(group, parsed, file),
		Member(parsed),
		Rawtype(parsed, file, group);
}