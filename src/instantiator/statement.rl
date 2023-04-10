INCLUDE "generator.rl"
INCLUDE "stage.rl"
INCLUDE "context.rl"

::rlc::instantiator::statement evaluate(
	p: ast::[resolver::Config]Statement #&,
	ctx: Context #&
) ast::[Config]Statement - std::Dyn
{
	TYPE SWITCH(p)
	{
	//! [Config::Prev]AssertStatement:
	//! [Config::Prev]DieStatement:
	//! [Config::Prev]YieldStatement:
	//! [Config::Prev]SleepStatement:
	ast::[Config::Prev]BlockStatement:
	{
		pp: ast::[Config::Prev]BlockStatement #& := >>p;
		s: ast::[Config]BlockStatement - std::Dyn := :a(BARE);
		_ctx: StatementContext := :childOf(&ctx, &s!);
		FOR(stmt ::= pp.Statements.start())
			s!.Statements += evaluate(stmt!, _ctx);
		= :<>(&&s);
	}
	//! ast::[Config::Prev]IfStatement:
	//! ast::[Config::Prev]VariableStatement:
	//! ast::[Config::Prev]ExpressionStatement:
	//! ast::[Config::Prev]ReturnStatement:
	//! ast::[Config::Prev]TryStatement:
	//! ast::[Config::Prev]ThrowStatement:
	//! ast::[Config::Prev]LoopStatement:
	//! ast::[Config::Prev]SwitchStatement:
	//! ast::[Config::Prev]TypeSwitchStatement:
	//! ast::[Config::Prev]BreakStatement:
	//! ast::[Config::Prev]ContinueStatement:
	}
}