INCLUDE "../parser/enum.rl"

::rlc::scoper Enum -> VIRTUAL ScopeItem, Scope
{
	Constant -> VIRTUAL ScopeItem, Member
	{
		Value: src::Size;

		# enum() Enum #\ := <<Enum \>>(parent());

		# FINAL type() Member::Type := :enumConstant;

		{
			parsed: parser::Enum::Constant #\,
			file: src::File#&,
			group: detail::ScopeItemGroup \}:
			ScopeItem(group, parsed, file),
			Member(parsed),
			Value(parsed->Value);
	}

	Constants: std::[Constant \]Vector;
	Size: src::Size;

	{
		parsed: parser::Enum #\,
		file: src::File#&,
		group: detail::ScopeItemGroup \}:
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
	# FINAL type() Global::Type := :enum;

	{
		parsed: parser::GlobalEnum #\,
		file: src::File#&,
		group: detail::ScopeItemGroup \}:
		ScopeItem(group, parsed, file),
		Enum(parsed, file, group);
}

::rlc::scoper MemberEnum -> Member, Enum
{
	# FINAL type() Member::Type := :enum;

	{
		parsed: parser::MemberEnum #\,
		file: src::File#&,
		group: detail::ScopeItemGroup \}:
		ScopeItem(group, parsed, file),
		Member(parsed),
		Enum(parsed, file, group);
}