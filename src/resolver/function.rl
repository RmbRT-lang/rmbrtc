INCLUDE "../scoper/function.rl"
INCLUDE "variable.rl"
INCLUDE "type.rl"
INCLUDE "statement.rl"
INCLUDE "scopeitem.rl"
INCLUDE "global.rl"
INCLUDE "member.rl"
INCLUDE "exprorstmt.rl"
INCLUDE 'std/tags'

::rlc::resolver Function VIRTUAL -> ScopeItem
{
	# FINAL type() ScopeItem::Type := :function;

	Arguments: LocalVariable - std::DynVector;
	Return: VariableType;
	Body: ExprOrStmt;
	Inline: BOOL;
	Coroutine: BOOL;

	{
		function: scoper::Function #\,
		cache: Cache &
	}->	ScopeItem(function, cache)
	:	Inline(function->Inline),
		Coroutine(function->Coroutine)
	{
		scope ::= &function->ArgumentScope;
		IF(function->Return.is_type())
			Return := :gc(<<<resolver::Type>>>(scope, function->Return.type()));
		ELSE
			Return := :gc(std::[resolver::Type::Auto]new(*function->Return.auto()));

		FOR(arg ::= function->Arguments.start(); arg; arg++)
			Arguments += :create(*arg, cache);

		IF(function->Body.is_expression())
			Body := :gc(<<<Expression>>>(&function->ArgumentScope, function->Body.expression()));
		ELSE IF(function->Body.is_statement())
			Body := :gc(<<<Statement>>>(function->Body.statement(), cache));
	}
}

::rlc::resolver GlobalFunction -> Global, Function
{
	{
		function: scoper::GlobalFunction #\,
		cache: Cache &
	}->	Function(function, cache);
}

::rlc::resolver MemberFunction -> Member, Function
{
	Abstractness: rlc::Abstractness;

	{
		function: scoper::MemberFunction #\,
		cache: Cache &
	}->	Member(function),
		Function(function, cache)
	:	Abstractness(function->Abstractness);
}

