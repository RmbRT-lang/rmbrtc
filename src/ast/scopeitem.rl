INCLUDE "templatedecl.rl"
INCLUDE "cache.rl"
INCLUDE "../error.rl"

(// All identifier-addressable code entities. /)
::rlc::ast [Stage: TYPE] ScopeItem VIRTUAL -> CodeObject
{
	(// The scope item's name. /)
	Name: Stage::Name;

	{name: Stage::Name+, position: src::Position} -> (position): Name := &&name;

	:transform{
		i: [Stage::Prev+]ScopeItem #&,
		f: Stage::PrevFile+,
		s: Stage &
	} -> (i):
		Name := s.transform_name(i.Name, f);

	<<<
		i: [Stage::Prev+]ScopeItem #&,
		f: Stage::PrevFile+,
		s: Stage &,
		parent: [Stage]ScopeBase \
	>>> ScopeItem - std::Dyn
	{
		IF(g ::= <<[Stage::Prev+]Global #*>>(&i))
			= :<>(<<<[Stage]Global>>>(*g, f, s, parent));
		ELSE IF(m ::= <<[Stage::Prev+]Member #*>>(&i))
			= :<>(<<<[Stage]Member>>>(*m, f, s, parent));
		ELSE
			= :<>(<<<[Stage]Local>>>(>>i, f, s, parent));
	}

	# THIS <> (rhs: THIS #&) S1 := Name <> rhs.Name;
}

::rlc::ast MergeError -> Error
{
	OldLoc: src::Position;

	[Stage: TYPE] {
		old: [Stage!]ScopeItem #\,
		new: [Stage!]ScopeItem #\
	} -> (new->Position):
		OldLoc := old->Position;

	# FINAL message(o: std::io::OStream &) VOID
	{
		std::io::write(o,
			"could not merge with previous occurrence\n",
			:stream(OldLoc), ": previously declared here.");
	}
}

/// An overloadable scope item that can hold multiple definitions from the same or included files.
(//
	Scope/overload lookup:
		1. check and return item, else, look for parent's includes.
		2. check all includes, but do not look at their includes.
/)
::rlc::ast [Stage: TYPE] MergeableScopeItem VIRTUAL -> [Stage]ScopeItem
{
	TYPE Prev := [Stage::Prev+]MergeableScopeItem;

	/// Definitions included from other files.
	Included: std::[std::str::CV; [Stage]MergeableScopeItem #\]Map;

	<<<
		p: [Stage::Prev+]MergeableScopeItem #&,
		f: Stage::PrevFile+,
		s: Stage &,
		parent: [Stage]ScopeBase \
	>>> THIS - std::Dyn
	{
		TYPE SWITCH(p)
		{
		[Stage::Prev+]Function:
			= :<>(<<<[Stage]Function>>>(>>p, f, s, parent));
		[Stage::Prev+]Namespace:
			= :a.[Stage]Namespace(:transform(>>p, f, s, parent));
		}
	}

	:transform{
		i: [Stage::Prev+]MergeableScopeItem #&,
		f: Stage::PrevFile+,
		s: Stage &,
		parent: [Stage]ScopeBase \
	} -> (:transform, i, f, s):
		Included := :reserve(##i.Included)
	{
		FOR(item ::= i.Included.start())
			include(s.MSIs![item!.Value, f, s, parent]);
	}

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