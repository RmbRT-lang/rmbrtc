INCLUDE "templatedecl.rl"
INCLUDE "cache.rl"
INCLUDE "instantiable.rl"
INCLUDE "../error.rl"

(// All identifier-addressable code entities. /)
::rlc::ast [Stage: TYPE] ScopeItem VIRTUAL -> CodeObject
{
	(// The scope item's name. /)
	Name: Stage::Name;
	_1: {std::NoCopy, std::NoMove}-std::Opt;

	{name: Stage::Name+, position: src::Position} -> (position): Name := &&name;

	:transform{
		i: [Stage::Prev+]ScopeItem #&,
		ctx: Stage::Context+ #&
	} -> (i):
		Name := ctx.transform_name(i.Name),
		_1 := :a
	{
		ctx.visit_scope_item(&i, &THIS);
	}

	<<<
		i: [Stage::Prev+]ScopeItem #&,
		ctx: Stage::Context+ #&
	>>> ScopeItem - std::Dyn
	{
		IF(g ::= <<[Stage::Prev+]Global #*>>(&i))
			= :<>(<<<[Stage]Global>>>(*g, ctx));
		ELSE IF(m ::= <<[Stage::Prev+]Member #*>>(&i))
			= :<>(<<<[Stage]Member>>>(*m, ctx));
		ELSE
			= :<>(<<<[Stage]Local>>>(>>i, ctx));
	}

	# THIS <> (rhs: THIS #&) S1 := Name <> rhs.Name;
}

::rlc::ast MergeError -> Error
{
	OldLoc: src::Position;

	[Stage1: TYPE; Stage2: TYPE] {
		old: [Stage1!]ScopeItem #\,
		new: [Stage2!]ScopeItem #\
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
	Included: [Stage]MergeableScopeItem #\ -std::VecSet;

	<<<
		p: [Stage::Prev+]MergeableScopeItem #&,
		ctx: Stage::Context+ #&
	>>> THIS - std::Dyn
	{
		TYPE SWITCH(p)
		{
		[Stage::Prev+]Function:
			= :<>(<<<[Stage]Function>>>(>>p, ctx));
		[Stage::Prev+]Namespace:
			= :a.[Stage]Namespace(:transform(>>p, ctx));
		}
	}

	:transform{
		i: [Stage::Prev+]MergeableScopeItem #&,
		ctx: Stage::Context+ #&
	} -> (:transform, i, ctx):
		Included := :reserve(##i.Included)
	{
	}

	/// Include definitions from another file.
	include(
		rhs: [Stage]MergeableScopeItem# \) VOID INLINE
	{
		ASSERT(TYPE(THIS) == TYPE(rhs));
		IF(Included.has(rhs))
			RETURN;

		include_impl(*rhs);
		Included += rhs;
	}

	/// Merge definitions from the same file into a single entity.
	merge(rhs: [Stage]MergeableScopeItem &&) VOID
	{
		ASSERT(TYPE(THIS) == TYPE(rhs));
		merge_impl(&&rhs);
	}

	PRIVATE ABSTRACT include_impl(rhs: [Stage]MergeableScopeItem #&) VOID;
	PRIVATE ABSTRACT merge_impl(rhs: [Stage]MergeableScopeItem &&) VOID;
}