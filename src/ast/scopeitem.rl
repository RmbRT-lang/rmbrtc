INCLUDE "templatedecl.rl"
INCLUDE "cache.rl"


(// All identifier-addressable code entities. /)
::rlc::ast [Stage: TYPE] ScopeItem VIRTUAL
{
	(// The scope item's name. /)
	Name: Stage::Name;

	{name: Stage::Name+}: Name := &&name;


	:transform{
		i: [Stage::Prev+]ScopeItem #&,
		f: Stage::PrevFile+,
		s: Stage &
	} (BARE);(/:
		Name := Stage::transform_name(i, f, s);/)

	<<<
		i: [Stage::Prev+]ScopeItem #&,
		f: Stage::PrevFile+,
		s: Stage &
	>>> ScopeItem - std::Dyn
	{
		IF(g ::= <<[Stage::Prev+]Global #*>>(&i))
			= <<<[Stage]Global>>>(*g, f, s);
		ELSE IF(m ::= <<[Stage::Prev+]Member #*>>(&i))
			= <<<[Stage]Member>>>(*m, f, s);
		ELSE
			= <<<[Stage]Local>>>(*<<[Stage::Prev+]Local #\>>(&i), f, s);
	}
}

::rlc::ast [Stage: TYPE] MergeError {
	Old: [Stage]ScopeItem \;
	New: [Stage]ScopeItem \;
}

/// An overloadable scope item that can hold multiple definitions.
::rlc::ast [Stage: TYPE] MergeableScopeItem VIRTUAL -> [Stage]ScopeItem
{
	TYPE Prev := [Stage::Prev+]MergeableScopeItem;

	Included: std::[std::str::CV; [Stage]MergeableScopeItem #\]AutoMap;

	:transform{
		i: [Stage::Prev+]MergeableScopeItem #&,
		f: Stage::PrevFile+,
		s: Stage &
	} (BARE); (/-> (:transform(i, f, s)):
		Included := :reserve(##i.Included)
	{
		FOR(item ::= i.Included.start())
			include(s.MSIs[item!.(1), f, s]);
	}/)

	/// Include definitions from another file.
	include(
		rhs: [Stage]MergeableScopeItem# \) VOID INLINE
	{
		ASSERT(TYPE(THIS) == TYPE(rhs));
		Included.insert(rhs->Name!, rhs);
	}

	/// Merge definitions from the same file into a single entity.
	merge(rhs: [Stage]MergeableScopeItem &&) VOID
	{
		ASSERT(TYPE(THIS) == TYPE(rhs));
		merge_impl(&&rhs);
	}

	PRIVATE ABSTRACT merge_impl(rhs: [Stage]MergeableScopeItem &&) VOID;
}