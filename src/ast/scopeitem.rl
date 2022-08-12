INCLUDE "templatedecl.rl"
INCLUDE "cache.rl"


(// All identifier-addressable code entities. /)
::rlc::ast [Stage: TYPE] ScopeItem VIRTUAL
{
	(// The scope item's name. /)
	Name: Stage::Name;

	:transform{
		i: [Stage::Prev+]ScopeItem #&,
		f: Stage #&
	}:
		Name := Stage::transform_name(i, f);

	<<<
		i: [Stage::Prev+]ScopeItem #&,
		f: Stage &
	>>> ScopeItem - std::Dyn
	{
		IF(g ::= <<[Stage::Prev+]Global #*>>(&i))
			= <<<[Stage]Global>>>(*g, f);
		ELSE IF(m ::= <<[Stage::Prev+]Member #*>>(&i))
			= <<<[Stage]Member>>>(*m, f);
		ELSE
			= <<<[Stage]Local>>>(*<<[Stage::Prev+]Local #\>>(&i), f);
	}
}

::rlc::ast [Stage: TYPE] MergeError {
	Old: [Stage]ScopeItem \;
	New: [Stage]ScopeItem \;
}

/// An overloadable scope item that can hold multiple definitions.
::rlc::ast [Stage: TYPE] MergeableScopeItem VIRTUAL -> [Stage]ScopeItem
{
	Included: std::[std::str::CV; [Stage]MergeableScopeItem #\]AutoMap;

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

	:transform{
		i: [Stage::Prev+]MergeableScopeItem #&,
		f: Stage #&,
		cache: THIS-[Stage]Cache &
	} -> (:transform(i, f)):
		Included := :reserve(##i.Included)
	{
		FOR(item ::= i.Included.start(); item; ++item)
			include(cache[i, f]);
	}

	PRIVATE ABSTRACT merge_impl(rhs: [Stage]MergeableScopeItem &&) VOID;
}