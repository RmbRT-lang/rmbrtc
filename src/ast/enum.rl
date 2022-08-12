INCLUDE "scopeitem.rl"
INCLUDE "../src/file.rl"

INCLUDE 'std/vector'

::rlc::ast [Stage: TYPE] Enum VIRTUAL -> [Stage]ScopeItem, CodeObject
{
	Constant -> [Stage]ScopeItem, [Stage]Member, CodeObject
	{
		Value: src::Index;

		:transform{e: [Stage::Prev+]Enum::Constant #&, f: Stage #&} ->
			(:transform(e, f)), (:transform(e, f)), (e):
			Value := e.Value;
	}

	Constants: std::[Constant]Vec;

	{};
	:transform{e: [Stage::Prev+]Enum #&, f: Stage #&} ->
		(:transform(e, f)), (e):
		Constants := :reserve(##e.Constants)
	{
		FOR(c ::= e.Constants.start(); c; ++c)
			Constants += :transform(c!.Value, f);
	}
}

::rlc::ast [Stage: TYPE] GlobalEnum -> [Stage]Global, [Stage]Enum
{
	:transform{e: [Stage::Prev+]GlobalEnum #&, f: Stage #&} ->
		(), (:transform(e, f));
}

::rlc::ast [Stage: TYPE] MemberEnum -> [Stage]Member, [Stage]Enum
{
	:transform{e: [Stage::Prev+]GlobalEnum #&, f: Stage #&} ->
		(e), (:transform(e, f));
}