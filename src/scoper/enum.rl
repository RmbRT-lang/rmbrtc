INCLUDE "../parser/enum.rl"

::rlc::scoper Enum -> VIRTUAL ScopeItem, Scope
{
	Constant -> VIRTUAL ScopeItem, Member
	{
		Value: src::Size;

		# enum() Enum #\ := [Enum \]dynamic_cast(parent());

		# FINAL type() Member::Type := Member::Type::enumConstant;

		CONSTRUCTOR(
			parsed: parser::Enum::Constant #\,
			file: src::File#&,
			group: detail::ScopeItemGroup \):
			ScopeItem(group, parsed, file),
			Member(parsed),
			Value(parsed->Value);
	}

	Constants: std::[Constant \]Vector;
	Size: src::Size;

	CONSTRUCTOR(
		parsed: parser::Enum #\,
		file: src::File#&,
		group: detail::ScopeItemGroup \):
		Scope(THIS, group->Scope),
		Size(parsed->Constants.back().Value+1)
	{
		FOR(i ::= 0; i < parsed->Constants.size(); i++)
		{
			c ::= Scope::insert(&parsed->Constants[i], file);
			Constants.push_back([Constant \]dynamic_cast(c));
		}
	}
}

::rlc::scoper GlobalEnum -> Global, Enum
{
	# FINAL type() Global::Type := Global::Type::enum;

	CONSTRUCTOR(
		parsed: parser::GlobalEnum #\,
		file: src::File#&,
		group: detail::ScopeItemGroup \):
		ScopeItem(group, parsed, file),
		Enum(parsed, file, group);
}

::rlc::scoper MemberEnum -> Member, Enum
{
	# FINAL type() Member::Type := Member::Type::enum;

	CONSTRUCTOR(
		parsed: parser::MemberEnum #\,
		file: src::File#&,
		group: detail::ScopeItemGroup \):
		ScopeItem(group, parsed, file),
		Member(parsed),
		Enum(parsed, file, group);
}