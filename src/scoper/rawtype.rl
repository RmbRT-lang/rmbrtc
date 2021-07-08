INCLUDE "../parser/rawtype.rl"
INCLUDE "expression.rl"
INCLUDE "scopeitem.rl"
INCLUDE "member.rl"
INCLUDE "scope.rl"

INCLUDE 'std/memory'

::rlc::scoper Rawtype VIRTUAL -> ScopeItem, Scope
{
	# FINAL type() ScopeItem::Type := :rawtype;

	Size: Expression - std::Dynamic;

	{
		parsed: parser::Rawtype #\,
		file: src::File #&,
		group: detail::ScopeItemGroup \
	}:	ScopeItem(group, parsed, file),
		Scope(&THIS, group->Scope),
		Size(:gc(Expression::create(parsed->Size, file)))
	{
		FOR(i ::= 0; i < ##parsed->Members; i++)
			Scope::insert(<<parser::ScopeItem #\>>(&*parsed->Members[i]), file);
	}
}

::rlc::scoper GlobalRawtype -> Global, Rawtype
{
	{
		parsed: parser::GlobalRawtype #\,
		file: src::File #&,
		group: detail::ScopeItemGroup \
	}:	Rawtype(parsed, file, group);
}

::rlc::scoper MemberRawtype -> Member, Rawtype
{
	{
		parsed: parser::MemberRawtype #\,
		file: src::File #&,
		group: detail::ScopeItemGroup \
	}:	Member(parsed),
		Rawtype(parsed, file, group);
}