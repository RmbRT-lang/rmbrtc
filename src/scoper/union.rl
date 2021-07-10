INCLUDE "../parser/union.rl"

INCLUDE "variable.rl"
INCLUDE "global.rl"
INCLUDE "member.rl"

::rlc::scoper Union VIRTUAL -> ScopeItem, Scope
{
	# FINAL type() ScopeItem::Type := :union;

	Fields: std::[MemberVariable \]Vector;

	{
		parsed: parser::Union #\,
		file: src::File#&,
		group: detail::ScopeItemGroup \
	}->	ScopeItem(group, parsed, file),
		Scope(&THIS, group->Scope)
	{
		FOR(i ::= 0; i < ##parsed->Members; i++)
		{
			member ::= Scope::insert(<<parser::ScopeItem #\>>(&*parsed->Members[i]), file);
			IF(var ::= <<MemberVariable \>>(member))
				IF(var->Attribute != MemberAttribute::static)
					Fields += var;
		}
	}
}

::rlc::scoper GlobalUnion -> Global, Union
{
	{
		parsed: parser::GlobalUnion #\,
		file: src::File#&,
		group: detail::ScopeItemGroup \
	}->	Union(parsed, file, group);
}

::rlc::scoper MemberUnion -> Member, Union
{
	{
		parsed: parser::MemberUnion #\,
		file: src::File#&,
		group: detail::ScopeItemGroup \
	}->	Member(parsed),
		Union(parsed, file, group);
}