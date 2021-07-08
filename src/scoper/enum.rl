INCLUDE "../parser/enum.rl"

::rlc::scoper Enum VIRTUAL -> ScopeItem, Scope
{
	# FINAL type() ScopeItem::Type := :enum;

	Constant -> ScopeItem, Member
	{
		Value: src::Size;

		# enum() Enum #\ := <<Enum #\>>(ScopeItem::parent());

		# FINAL type() ScopeItem::Type := :enumConstant;

		{
			parsed: parser::Enum::Constant #\,
			file: src::File#&,
			group: detail::ScopeItemGroup \
		}:	ScopeItem(group, parsed, file),
			Member(parsed),
			Value(parsed->Value);
	}

	Constants: std::[Constant \]Vector;
	Size: src::Size;

	{
		parsed: parser::Enum #\,
		file: src::File#&,
		group: detail::ScopeItemGroup \
	}:	ScopeItem(group, parsed, file),
		Scope(&THIS, group->Scope),
		Size(parsed->Constants.back().Value+1)
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
		file: src::File#&,
		group: detail::ScopeItemGroup \
	}:	Enum(parsed, file, group);
}

::rlc::scoper MemberEnum -> Member, Enum
{
	{
		parsed: parser::MemberEnum #\,
		file: src::File#&,
		group: detail::ScopeItemGroup \
	}:	Member(parsed),
		Enum(parsed, file, group);
}