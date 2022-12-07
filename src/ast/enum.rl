INCLUDE "scopeitem.rl"
INCLUDE "../src/file.rl"

INCLUDE 'std/vector'

::rlc::ast [Stage: TYPE] Enum VIRTUAL -> [Stage]ScopeItem, [Stage]ScopeBase
{
	Constant -> [Stage]ScopeItem
	{
		Value: src::Index;

		:transform{
			e: [Stage::Prev+]Enum::Constant #&,
			f: Stage::PrevFile+,
			s: Stage &
		} -> (:transform, e, f, s):
			Value := e.Value;
	}

	Constants: std::[Constant]VecSet;

	:transform{
		e: [Stage::Prev+]Enum #&,
		f: Stage::PrevFile+,
		s: Stage &,
		parent: [Stage]ScopeBase \
	} ->
		(:transform, e, f, s), (:childOf, parent):
		Constants := :reserve(##e.Constants)
	{
		FOR(c ::= e.Constants.start())
			Constants += <Constant>(:transform(c!, f, s));
	}
}

::rlc::ast [Stage: TYPE] GlobalEnum -> [Stage]Global, [Stage]Enum
{
	:transform{
		e: [Stage::Prev+]GlobalEnum #&,
		f: Stage::PrevFile+,
		s: Stage &,
		parent: [Stage]ScopeBase \
	} -> (), (:transform, e, f, s, parent);
}

::rlc::ast [Stage: TYPE] MemberEnum -> [Stage]Member, [Stage]Enum
{
	:transform{
		e: [Stage::Prev+]MemberEnum #&,
		f: Stage::PrevFile+,
		s: Stage &,
		parent: [Stage]ScopeBase \
	} -> (:transform, e), (:transform, e, f, s, parent);
}