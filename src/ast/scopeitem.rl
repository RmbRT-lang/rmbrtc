INCLUDE "templatedecl.rl"



(// All identifier-addressable code entities. /)
::rlc::ast [Stage: TYPE] ScopeItem VIRTUAL
{
	(// The scope item's name. /)
	Name: Stage::Name;
}

::rlc::ast [Stage: TYPE] MergeError {
	Old: [Stage]ScopeItem \;
	New: [Stage]ScopeItem \;
}

/// An overloadable scope item that can hold multiple definitions.
::rlc::ast [Stage: TYPE] MergeableScopeItem VIRTUAL -> [Stage]ScopeItem
{
	PrivateIncluded: [Stage]MergeableScopeItem# \ - std::Vec;
	PublicIncluded: [Stage]MergeableScopeItem# \ - std::Vec;

	/// Include definitions from another file.
	include(
		rhs: [Stage]MergeableScopeItem# \,
		public: BOOL) VOID INLINE
	{
		(public ? PublicIncluded : PrivateIncluded) += rhs;
	}


	/// Merge definitions from the same file into a single entity.
	merge(rhs: [Stage]MergeableScopeItem &&) VOID
	{
		ASSERT(TYPE(THIS) == TYPE(rhs));
		merge_impl(&&rhs);
	}

	PRIVATE ABSTRACT merge_impl(rhs: [Stage]MergeableScopeItem &&) VOID;
}