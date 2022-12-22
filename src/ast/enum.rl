INCLUDE "scopeitem.rl"
INCLUDE "../src/file.rl"

INCLUDE 'std/vector'

::rlc::ast [Stage: TYPE] Enum VIRTUAL ->
	[Stage]ScopeItem,
	[Stage]ScopeBase,
	[Stage]CoreType
{
	Constant -> [Stage]ScopeItem
	{
		Value: src::Index;

		:transform{
			e: [Stage::Prev+]Enum::Constant #&,
			ctx: Stage::Context+ #&
		} -> (:transform, e, ctx):
			Value := e.Value;
	}

	Constants: std::[Constant]DynVecSet;

	:transform{
		e: [Stage::Prev+]Enum #&,
		ctx: Stage::Context+ #&
	} ->
		(:transform, e, ctx), (:childOf, ctx.Parent), ():
		Constants := :reserve(##e.Constants)
	{
		FOR(c ::= e.Constants.start())
			Constants += :transform(c!, ctx);
	}

	#? FINAL scope_item(name: Stage::Name #&) [Stage]ScopeItem #? *
	{
		c: Constant (BARE);
		c.Name := name;
		IF(found ::= Constants.find(&c))
			= &found!;
		= NULL;
	}

	#? FINAL local(Stage::Name #&, LocalPosition) [Stage]ScopeItem #? * := NULL;
}

::rlc::ast [Stage: TYPE] GlobalEnum -> [Stage]Global, [Stage]Enum
{
	:transform{
		e: [Stage::Prev+]GlobalEnum #&,
		ctx: Stage::Context+ #&
	} -> (), (:transform, e, ctx);
}

::rlc::ast [Stage: TYPE] MemberEnum -> [Stage]Member, [Stage]Enum
{
	:transform{
		e: [Stage::Prev+]MemberEnum #&,
		ctx: Stage::Context+ #&
	} -> (:transform, e), (:transform, e, ctx);
}