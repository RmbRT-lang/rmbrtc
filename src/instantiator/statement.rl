INCLUDE "generator.rl"
INCLUDE "stage.rl"
INCLUDE "context.rl"


::rlc::instantiator::statement evaluate_inner(
	p: ast::[resolver::Config]Statement #&,
	ctx: Context #&
) ast::[Config]Statement - std::Val
{
	TYPE SWITCH(p)
	{
	//! [Config::Prev]AssertStatement:
	ast::[Config::Prev]DieStatement:
	{
		stmt: ast::[Config]DieStatement-std::Val := :a(BARE);
		pp: ast::[Config::Prev]DieStatement #& := >>p;
		IF(pp.Message)
		{
			stmt.mut_ok().Message := :a(BARE);
			stmt.mut_ok().Message!.String := pp.Message!.String;
		}
		= :<>(&&stmt);
	}
	ast::[Config::Prev]YieldStatement: = :a.ast::[Config]YieldStatement (BARE);
	//! [Config::Prev]SleepStatement:
	ast::[Config::Prev]BlockStatement:
	{
		pp: ast::[Config::Prev]BlockStatement #& := >>p;
		s: ast::[Config]BlockStatement - std::Val := :a(BARE);
		_ctx: StatementContext := :childOf(&ctx, s.mut_ptr_ok());
		FOR(stmt ::= pp.Statements.start())
			s.mut_ok().Statements += evaluate(stmt!, _ctx);
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
		stmt: ast::[Config]BreakStatement-std::Val := :a(BARE);
		parentStmt ::= ctx.[StatementContext]nearest()->Statement;
		WHILE(--breakDist)
			parentStmt := parentStmt->Parent;
		stmt.mut_ok().Label := :a(<<ast::[Config]LabelledStatement \>>(parentStmt));
		= :<>(&&stmt);
	}
	ast::[Config::Prev]ContinueStatement:
	{
		contDist ::= <<ast::[Config::Prev]BreakStatement#&>>(p).Label!;
		stmt: ast::[Config]ContinueStatement-std::Val := :a(BARE);
		parentStmt ::= ctx.[StatementContext]nearest()->Statement;
		WHILE(--contDist)
			parentStmt := parentStmt->Parent;
		stmt.mut_ok().Label := :a(<<ast::[Config]LabelledStatement \>>(parentStmt));
		= :<>(&&stmt);
	}
	}
}

::rlc::instantiator::statement evaluate(
	p: ast::[resolver::Config]Statement #&,
	ctx: Context #&
) ast::[Config]Statement - std::Val {
	x ::= evaluate_inner(p, ctx);
	IF(stmtCtx ::= ctx.[StatementContext]nearest())
		x.mut_ok().Parent := stmtCtx->Statement;
	= &&x;
}