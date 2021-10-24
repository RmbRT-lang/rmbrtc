INCLUDE "../parser/enum.rl"

::rlc::scoper Enum VIRTUAL -> ScopeItem, Scope
{
	Constant -> ScopeItem, Member
	{
		Value: src::Size;

		# enum() Enum #\ := <<Enum #\>>(ScopeItem::parent());

		{
			parsed: parser::Enum::Constant #\,
			file: parser::File#&,
			group: detail::ScopeItemGroup \
		}->	ScopeItem(group, parsed, file),
			Member(parsed)
		:	Value(parsed->Value);
	}

	Constants: std::[Constant \]Vector;
	Size: src::Size;

	{
		parsed: parser::Enum #\,
		file: parser::File#&,
		group: detail::ScopeItemGroup \
	}->	ScopeItem(group, parsed, file),
		Scope(&THIS, group->Scope)
	:	Size(parsed->Constants!.back().Value+1)
	{
		FOR(i ::= 0; i < ##parsed->Constants; i++)
		{
			c ::= Scope::insert(&parsed->Constants[i], file);
			Constants += <<Constant \>>(c);
		}
	}
}

::rlc::scoper GlobalEnum -> Global, Enum
{
	{
		parsed: parser::GlobalEnum #\,
		file: parser::File#&,
		group: detail::ScopeItemGroup \
	}->	Enum(parsed, file, group);
}

::rlc::scoper MemberEnum -> Member, Enum
{
	{
		parsed: parser::MemberEnum #\,
		file: parser::File#&,
		group: detail::ScopeItemGroup \
	}->	Member(parsed),
		Enum(parsed, file, group);
}