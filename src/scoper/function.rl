INCLUDE "../parser/function.rl"

INCLUDE "global.rl"
INCLUDE "member.rl"
INCLUDE "scopeitem.rl"
INCLUDE "scope.rl"
INCLUDE "variable.rl"
INCLUDE "exprorstmt.rl"


::rlc::scoper Function -> VIRTUAL ScopeItem
{
	Arguments: std::[LocalVariable\]Vector;
	Return: std::[Type]Dynamic;
	Body: ExprOrStmt;
	Inline: bool;
	Coroutine: bool;

	ArgumentScope: Scope;

	{
		parsed: parser::Function #\,
		file: src::File#&,
		group: detail::ScopeItemGroup \}:
		Inline(parsed->IsInline),
		Coroutine(parsed->IsCoroutine),
		ArgumentScope(&THIS, group->Scope)
	{
		FOR(i ::= 0; i < parsed->Arguments.size(); i++)
		{
			var ::= ArgumentScope.insert(&parsed->Arguments[i], file);
			Arguments += [LocalVariable \]dynamic_cast(var);
		}

		IF(parsed->Return)
			Return := :gc(Type::create(parsed->Return, file));

		IF(parsed->Body.is_expression())
			Body := Expression::create(parsed->Body.expression(), file);
		ELSE IF(parsed->Body.is_statement())
			Body := Statement::create(0, parsed->Body.statement(), file, &ArgumentScope);
	}
}

::rlc::scoper GlobalFunction -> Global, Function
{
	# FINAL type() Global::Type := :function;

	{
		parsed: parser::GlobalFunction #\,
		file: src::File#&,
		group: detail::ScopeItemGroup \}:
		ScopeItem(group, parsed, file),
		Function(parsed, file, group);
}

::rlc::scoper MemberFunction -> Member, Function
{
	# FINAL type() Member::Type := :function;

	{
		parsed: parser::MemberFunction #\,
		file: src::File#&,
		group: detail::ScopeItemGroup \}:
		ScopeItem(group, parsed, file),
		Function(parsed, file, group),
		Member(parsed);
}