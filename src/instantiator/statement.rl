INCLUDE "generator.rl"
INCLUDE "stage.rl"
INCLUDE "context.rl"


::rlc::instantiator::statement evaluate_inner(
	p: ast::[resolver::Config]Statement #&,
	ctx: Context #&
) ast::[Config]Statement - std::Dyn
{
	TYPE SWITCH(p)
	{
	//! [Config::Prev]AssertStatement:
	ast::[Config::Prev]DieStatement:
	{
		stmt: ast::[Config]DieStatement-std::Dyn := :a(BARE);
		pp: ast::[Config::Prev]DieStatement #& := >>p;
		IF(pp.Message)
		{
			stmt!.Message := :a(BARE);
			stmt!.Message!.String := pp.Message!.String;
		}
		= :<>(stmt);
	}
	ast::[Config::Prev]YieldStatement: = :a.ast::[Config]YieldStatement (BARE);
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
	ast::[Config::Prev]BreakStatement:
	{
		breakDist ::= <<ast::[Config::Prev]BreakStatement#&>>(p).Label!;
		stmt: ast::[Config]BreakStatement-std::Dyn := :a(BARE);
		parentStmt ::= ctx.[StatementContext]nearest()->Statement;
		WHILE(--breakDist)
			parentStmt := parentStmt->Parent;
		stmt->Label := :a(<<ast::[Config]LabelledStatement \>>(parentStmt));
		= :<>(&&stmt);
	}
	ast::[Config::Prev]ContinueStatement:
	{
		contDist ::= <<ast::[Config::Prev]BreakStatement#&>>(p).Label!;
		stmt: ast::[Config]ContinueStatement-std::Dyn := :a(BARE);
		parentStmt ::= ctx.[StatementContext]nearest()->Statement;
		WHILE(--contDist)
			parentStmt := parentStmt->Parent;
		stmt->Label := :a(<<ast::[Config]LabelledStatement \>>(parentStmt));
		= :<>(&&stmt);
	}
	}
}

::rlc::instantiator::statement evaluate(
	p: ast::[resolver::Config]Statement #&,
	ctx: Context #&
) ast::[Config]Statement - std::Dyn {
	x ::= evaluate_inner(p, ctx);
	IF(stmtCtx ::= ctx.[StatementContext]nearest())
		x!.Parent := stmtCtx->Statement;
	= &&x;
}