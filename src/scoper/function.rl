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
	Return: VariableType;
	Body: ExprOrStmt;
	Inline: BOOL;
	Coroutine: BOOL;

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
			Arguments += <<LocalVariable \>>(var);
		}

		ASSERT(parsed->Return);
		IF(parsed->Return.is_type())
			Return := Type::create(parsed->Return.type(), file);
		ELSE
			Return := ::[Type::Auto]new(*parsed->Return.auto());

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

	Abstractness: rlc::Abstractness;

	{
		parsed: parser::MemberFunction #\,
		file: src::File#&,
		group: detail::ScopeItemGroup \}:
		ScopeItem(group, parsed, file),
		Function(parsed, file, group),
		Member(parsed),
		Abstractness(parsed->Abstractness);
}