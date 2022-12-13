INCLUDE "../ast/varorexpression.rl"
INCLUDE "parser.rl"
INCLUDE "stage.rl"
INCLUDE "expression.rl"
INCLUDE "variable.rl"

INCLUDE 'std/dyn'

::rlc::parser::var_or_exp parse_opt(
	p: Parser &
) ast::[Config]VarOrExpr-std::DynOpt
{
	IF(variable::help::is_named_variable_start(p, TRUE))
	{
		IF(v ::= variable::parse_local(p, FALSE))
			= &&v;
		p.fail("expected variable");
	}
	= expression::parse(p);
}

::rlc::parser::var_or_exp parse(p: Parser &) ast::[Config]VarOrExpr-std::Dyn
{
	IF:!(ret ::= parse_opt(p))
		p.fail("expected variable or expression");
	= :!(&&ret);
}