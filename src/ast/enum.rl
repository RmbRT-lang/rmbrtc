INCLUDE "scopeitem.rl"
INCLUDE "../src/file.rl"

INCLUDE 'std/vector'

::rlc::ast [Stage: TYPE] Enum VIRTUAL -> [Stage]ScopeItem, CodeObject
{
	Constant -> [Stage]ScopeItem, [Stage]Member, CodeObject
	{
		Value: src::Index;

		:transform{
			e: [Stage::Prev+]Enum::Constant #&,
			f: Stage::PrevFile+,
			s: Stage &
		} -> (:transform, e, f, s), (:transform, e), (e):
			Value := e.Value;
	}

	Constants: std::[Constant]Vec;

	{};
	:transform{
		e: [Stage::Prev+]Enum #&,
		f: Stage::PrevFile+,
		s: Stage &
	} ->
		(:transform, e, f, s), (e):
		Constants := :reserve(##e.Constants)
	{
		FOR(c ::= e.Constants.start())
			Constants += :transform(c!, f, s);
	}
}

::rlc::ast [Stage: TYPE] GlobalEnum -> [Stage]Global, [Stage]Enum
{
	:transform{
		e: [Stage::Prev+]GlobalEnum #&,
		f: Stage::PrevFile+,
		s: Stage &
	} -> (), (:transform, e, f, s);
}

::rlc::ast [Stage: TYPE] MemberEnum -> [Stage]Member, [Stage]Enum
{
	:transform{
		e: [Stage::Prev+]MemberEnum #&,
		f: Stage::PrevFile+,
		s: Stage &
	} -> (:transform, e), (:transform, e, f, s);
}