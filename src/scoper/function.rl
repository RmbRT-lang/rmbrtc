INCLUDE "../parser/function.rl"

INCLUDE "global.rl"
INCLUDE "member.rl"
INCLUDE "scopeitem.rl"
INCLUDE "scope.rl"
INCLUDE "variable.rl"
INCLUDE "exprorstmt.rl"

::rlc::scoper Function VIRTUAL -> ScopeItem
{
	# FINAL type() ScopeItem::Type := :function;

	Arguments: std::[LocalVariable\]Vector;
	Return: VariableType;
	Body: ExprOrStmt;
	Inline: BOOL;
	Coroutine: BOOL;

	ArgumentScope: Scope;

	{
		parsed: parser::Function #\,
		file: src::File#&,
		group: detail::ScopeItemGroup \
	}->	ScopeItem(group, parsed, file)
	:	Inline(parsed->IsInline),
		Coroutine(parsed->IsCoroutine),
		ArgumentScope(&THIS, group->Scope)
	{
		FOR(i ::= 0; i < ##parsed->Arguments; i++)
		{
			var ::= ArgumentScope.insert(&parsed->Arguments[i], file);
			Arguments += <<LocalVariable \>>(var);
			Arguments.back()->Position := 0;
		}

		ASSERT(parsed->Return);
		IF(parsed->Return.is_type())
			Return := :gc(scoper::Type::create(parsed->Return.type(), file));
		ELSE
			Return := :gc(std::[scoper::Type::Auto]new(*parsed->Return.auto()));

		IF(parsed->Body.is_expression())
			Body := :gc(Expression::create(0, parsed->Body.expression(), file));
		ELSE IF(parsed->Body.is_statement())
			Body := :gc(Statement::create(0, parsed->Body.statement(), file, &ArgumentScope));
	}
}

::rlc::scoper GlobalFunction -> Global, Function
{
	{
		parsed: parser::GlobalFunction #\,
		file: src::File#&,
		group: detail::ScopeItemGroup \
	}->	Function(parsed, file, group);
}

::rlc::scoper MemberFunction -> Member, Function
{
	Abstractness: rlc::Abstractness;

	{
		parsed: parser::MemberFunction #\,
		file: src::File#&,
		group: detail::ScopeItemGroup \
	}->	Function(parsed, file, group),
		Member(parsed)
	:	Abstractness(parsed->Abstractness);
}