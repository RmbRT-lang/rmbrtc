INCLUDE "../ast/varorexpression.rl"
INCLUDE "parser.rl"
INCLUDE "stage.rl"
INCLUDE "expression.rl"
INCLUDE "variable.rl"

INCLUDE 'std/dyn'

::rlc::parser::var_or_exp parse(p: Parser &) ast::[Config]VarOrExpr-std::Dyn
{
	IF(variable::help::is_named_variable_start(p))
	{
		IF(v ::= variable::parse_local(p, FALSE, locals))
			= &&v;
		p.fail("expected variable");
	}
	= expression::parse(p);
}