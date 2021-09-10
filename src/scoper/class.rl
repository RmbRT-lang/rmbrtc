INCLUDE "../parser/class.rl"

INCLUDE "global.rl"
INCLUDE "member.rl"
INCLUDE "scopeitem.rl"
INCLUDE "symbol.rl"

::rlc::scoper Class VIRTUAL -> ScopeItem, Scope
{
	Inheritance
	{
		Visibility: rlc::Visibility;
		IsVirtual: BOOL;
		Type: Symbol;

		{
			parsed: parser::Class::Inheritance #&,
			file: src::File #&
		}:	Visibility(parsed.Visibility),
			IsVirtual(parsed.IsVirtual),
			Type(parsed.Type, file);
	}

	{
		parsed: parser::Class #\,
		file: src::File #&,
		group: detail::ScopeItemGroup \
	}->	ScopeItem(group, parsed, file),
		Scope(&THIS, group->Scope)
	:	Virtual(parsed->Virtual)
	{
		FOR(i ::= 0; i < ##parsed->Members; i++)
			Scope::insert(<<parser::ScopeItem #\>>(parsed->Members[i]), file);

		FOR(i ::= 0; i < ##parsed->Inheritances; i++)
			Inheritances += (parsed->Inheritances[i], file);
	}

	Virtual: BOOL;
	Inheritances: std::[Inheritance]Vector;
}

::rlc::scoper GlobalClass -> Global, Class
{
	{
		parsed: parser::GlobalClass #\,
		file: src::File #&,
		group: detail::ScopeItemGroup \
	}->	Class(parsed, file, group);
}

::rlc::scoper MemberClass -> Member, Class
{
	{
		parsed: parser::MemberClass #\,
		file: src::File #&,
		group: detail::ScopeItemGroup \
	}->	Member(parsed),
		Class(parsed, file, group);
}