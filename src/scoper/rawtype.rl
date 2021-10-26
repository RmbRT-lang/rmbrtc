INCLUDE "../parser/rawtype.rl"
INCLUDE "expression.rl"
INCLUDE "scopeitem.rl"
INCLUDE "member.rl"
INCLUDE "scope.rl"

INCLUDE 'std/memory'

::rlc::scoper Rawtype VIRTUAL -> ScopeItem, Scope
{
	Size: Expression - std::Dynamic;

	{
		parsed: parser::Rawtype #\,
		file: parser::File #&,
		group: detail::ScopeItemGroup \
	}->	ScopeItem(group, parsed, file),
		Scope(&THIS, group->Scope)
	:	Size(:gc(<<<Expression>>>(parsed->Size, file.Src)))
	{
		FOR(i ::= 0; i < ##parsed->Members; i++)
			Scope::insert(<<parser::ScopeItem #\>>(parsed->Members[i]), file);
	}
}

::rlc::scoper GlobalRawtype -> Global, Rawtype
{
	{
		parsed: parser::GlobalRawtype #\,
		file: parser::File #&,
		group: detail::ScopeItemGroup \
	}->	Rawtype(parsed, file, group);
}

::rlc::scoper MemberRawtype -> Member, Rawtype
{
	{
		parsed: parser::MemberRawtype #\,
		file: parser::File #&,
		group: detail::ScopeItemGroup \
	}->	Member(parsed),
		Rawtype(parsed, file, group);
}