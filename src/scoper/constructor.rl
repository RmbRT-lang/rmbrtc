INCLUDE "../parser/constructor.rl"

INCLUDE "member.rl"
INCLUDE "scope.rl"
INCLUDE "detail/statement.rl"

::rlc::scoper Constructor -> Member, ScopeItem
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
			FOR(i ::= 0; i < ##parsed.Arguments; i++)
				Arguments += :gc(Expression::create(parsed.Arguments[i], file));
		}
	}

	MemberInit
	{
		Member: String;
		Position: src::Position;
		Arguments: std::[std::[Expression]Dynamic]Vector;

		{
			parsed: parser::Constructor::MemberInit #&,
			file: src::File#&
		}:	Member(file.content(parsed.Member)),
			Position(parsed.Position)
		{
			FOR(i ::= 0; i < ##parsed.Arguments; i++)
				Arguments += :gc(Expression::create(parsed.Arguments[i], file));
		}
	}

	ArgScope: Scope;
	Arguments: std::[LocalVariable \]Vector;
	BaseInits: std::[BaseInit]Vector;
	MemberInits: std::[MemberInit] Vector;
	Body: std::[BlockStatement]Dynamic;
	Inline: BOOL;

	# FINAL type() ScopeItem::Type := :constructor;

	{
		parsed: parser::Constructor #\,
		file: src::File#&,
		group: detail::ScopeItemGroup \}:
		Member(parsed),
		ScopeItem(group, parsed, file),
		ArgScope(&THIS, group->Scope),
		Inline(parsed->Inline)
	{
		FOR(i ::= 0; i < ##parsed->Arguments; i++)
		{
			arg ::= ArgScope.insert(&parsed->Arguments[i], file);
			local ::= <<LocalVariable \>>(arg);
			local->set_position(0);
			Arguments += local;
		}

		FOR(i ::= 0; i < ##parsed->BaseInits; i++)
			BaseInits += (parsed->BaseInits[i], file);

		FOR(i ::= 0; i < ##parsed->MemberInits; i++)
			MemberInits += (parsed->MemberInits[i], file);

		IF(parsed->Body)
			Body := :gc(std::[BlockStatement]new(0, parsed->Body, file, &ArgScope));
	}
}