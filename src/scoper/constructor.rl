INCLUDE "../parser/constructor.rl"

INCLUDE "member.rl"
INCLUDE "scope.rl"
INCLUDE "detail/statement.rl"

::rlc::scoper Constructor -> Member, VIRTUAL ScopeItem
{
	BaseInit
	{
		Base: Symbol;
		Arguments: std::[std::[Expression]Dynamic]Vector;
		{
			parsed: parser::Constructor::BaseInit #&,
			file: src::File#&}:
			Base(parsed.Base, file)
		{
			FOR(i ::= 0; i < parsed.Arguments.size(); i++)
				Arguments.push_back(
					Expression::create(parsed.Arguments[i], file));
		}
	}

	MemberInit
	{
		Member: String;
		Arguments: std::[std::[Expression]Dynamic]Vector;

		{
			parsed: parser::Constructor::MemberInit #&,
			file: src::File#&}:
			Member(file.content(parsed.Member))
		{
			FOR(i ::= 0; i < parsed.Arguments.size(); i++)
				Arguments.push_back(
					Expression::create(parsed.Arguments[i], file));
		}
	}

	ArgScope: Scope;
	Arguments: std::[LocalVariable \]Vector;
	BaseInits: std::[BaseInit]Vector;
	MemberInits: std::[MemberInit] Vector;
	Body: std::[BlockStatement]Dynamic;
	Inline: bool;

	# FINAL type() Member::Type := Member::Type::constructor;

	{
		parsed: parser::Constructor #\,
		file: src::File#&,
		group: detail::ScopeItemGroup \}:
		Member(parsed),
		ScopeItem(group, parsed, file),
		ArgScope(THIS, group->Scope),
		Inline(parsed->Inline)
	{
		FOR(i ::= 0; i < parsed->Arguments.size(); i++)
		{
			arg ::= ArgScope.insert(&parsed->Arguments[i], file);
			Arguments.push_back([LocalVariable \]dynamic_cast(arg));
		}

		FOR(i ::= 0; i < parsed->BaseInits.size(); i++)
			BaseInits.emplace_back(parsed->BaseInits[i], file);

		FOR(i ::= 0; i < parsed->MemberInits.size(); i++)
			MemberInits.emplace_back(parsed->MemberInits[i], file);

		IF(parsed->Body)
			Body := [BlockStatement]new(0, parsed->Body, file, &ArgScope);
	}
}