INCLUDE "global.rl"
INCLUDE "scopeitem.rl"
INCLUDE "statement.rl"
INCLUDE "codeobject.rl"

::rlc::ast [Stage:TYPE] Test -> [Stage]Global, CodeObject, [Stage]Instantiable
{
	Name: Stage::String;
	Body: [Stage]BlockStatement;

	:transform{
		p: [Stage::Prev+]Test #&,
		ctx: Stage::Context+ #&
	} -> (), (p), ():
		Name := ctx.transform_string(p.Name),
		Body := :transform(p.Body, ctx);
}