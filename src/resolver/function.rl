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

	Arguments: LocalVariable - std::Vector;
	Return: VariableType;
	Body: ExprOrStmt;
	Inline: BOOL;
	Coroutine: BOOL;

	{
		function: scoper::Function #\
	}:	ScopeItem(function),
		Inline(function->Inline),
		Coroutine(function->Coroutine)
	{
		scope ::= &function->ArgumentScope;
		IF(function->Return.is_type())
			Return := :gc(resolver::Type::create(scope, function->Return.type()));
		ELSE
			Return := :gc(std::[resolver::Type::Auto]new(*function->Return.auto()));

		FOR(arg ::= function->Arguments.start(); arg; arg++)
			Arguments += *arg;

		IF(function->Body.is_expression())
			Body := :gc(Expression::create(&function->ArgumentScope, function->Body.expression()));
		ELSE IF(function->Body.is_statement())
			Body := :gc(Statement::create(function->Body.statement()));
	}
}

::rlc::resolver GlobalFunction -> Global, Function
{
	{
		function: scoper::GlobalFunction #\
	}:	Function(function);
}

::rlc::resolver MemberFunction -> Member, Function
{
	Abstractness: rlc::Abstractness;

	{
		function: scoper::MemberFunction #\
	}:	Member(function),
		Function(function),
		Abstractness(function->Abstractness);
}

