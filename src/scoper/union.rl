INCLUDE "../parser/union.rl"

INCLUDE "variable.rl"
INCLUDE "global.rl"
INCLUDE "member.rl"

::rlc::scoper Union -> VIRTUAL ScopeItem, Scope
{
	Fields: std::[MemberVariable \]Vector;

	CONSTRUCTOR(
		parsed: parser::Union #\,
		file: src::File#&,
		group: detail::ScopeItemGroup \):
		Scope(THIS, group->Scope)
	{
		FOR(i ::= 0; i < parsed->Members.size(); i++)
		{
			member ::= Scope::insert(parsed->Members[i], file);
			IF(var ::= [MemberVariable \]dynamic_cast(member))
				IF(var->Attribute != MemberAttribute::static)
					Fields.push_back(var);
		}
	}
}

::rlc::scoper GlobalUnion -> Global, Union
{
	# type() Global::Type := Global::Type::union;

	CONSTRUCTOR(
		parsed: parser::GlobalUnion #\,
		file: src::File#&,
		group: detail::ScopeItemGroup \):
		ScopeItem(group, parsed, file),
		Union(parsed, file, group);
}

::rlc::scoper MemberUnion -> Member, Union
{
	# type() Member::Type := Member::Type::union;

	CONSTRUCTOR(
		parsed: parser::MemberUnion #\,
		file: src::File#&,
		group: detail::ScopeItemGroup \):
		ScopeItem(group, parsed, file),
		Member(parsed),
		Union(parsed, file, group);
}