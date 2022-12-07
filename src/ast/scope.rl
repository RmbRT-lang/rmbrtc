/// A generic scope. The actual contents of the scope are in specialised scope types for more type safety.
::rlc::ast [Stage: TYPE] ScopeBase VIRTUAL
{
	// This file's parent of this scope.
	Parent: [Stage]ScopeBase *;
	:childOf{p: [Stage]ScopeBase \}: Parent := p;
	:root{}: Parent := NULL;
}

/// A strongly typed scope.
::rlc::ast [Stage: TYPE; Name: TYPE; Elem: TYPE] Scope -> [Stage]ScopeBase
{
	// This scope's elements coming from this file only.
	Elements: std::[Name #-std::Ref; Elem-std::Dyn]Map;

	std::NoCopy;
	std::NoMove;

	:childOf{parent: [Stage]ScopeBase \} -> (:childOf, parent);

	[Prev: TYPE]
	:transform{
		p: Prev! #&,
		f: Stage::PrevFile+,
		s: Stage &,
		parent: [Stage]ScopeBase \
	} -> (:childOf, parent):
		Elements := :reserve(##p.Elements)
	{
		FOR(e ::= p.Elements.start())
			THIS += :make(e!.Value!, f, s, &THIS);
	}

	#? start() ? INLINE := Elements.start();
	#? end() ? INLINE := Elements.end();

	THIS[n: Name#&] Elem *
	{
		IF(e ::= Elements.find(n))
			= &(*e)!;
		= NULL;
	}

	merge_locally(rhs: THIS &&) VOID
	{
		FOR(kv ::= rhs.Elements.start())
			insert_or_merge(kv!.Value);
		rhs := BARE;
	}

	insert_or_merge(entry: Elem-std::Dyn) VOID
	{
		name ::= &<<[Stage]ScopeItem #&>>(entry!).Name;
		IF:!(existing ::= Elements.find(name))
			ASSERT( THIS += &&entry );
		ELSE
		{
			new ::= <<[Stage]ScopeItem \>>(entry);
			old ::= <<[Stage]ScopeItem \>>(*existing);
			IF:!(merge_lhs ::= <<[Stage]MergeableScopeItem *>>(old))
				THROW <MergeError>(old, new);
			IF:!(merge_rhs ::= <<[Stage]MergeableScopeItem *>>(new))
				THROW <MergeError>(old, new);
			merge_lhs->merge(&&*merge_rhs);
		}
	}

	insert(v: Elem-std::Dyn) BOOL
		:= Elements.insert(&<<[Stage]ScopeItem #&>>(v!).Name, &&v);

	THIS += (v: Elem-std::Dyn) BOOL INLINE := insert(&&v);
}

::rlc::ast [Stage:TYPE] TYPE MemberScope :=
	[Stage; Stage::Name+; ast::[Stage]Member+]Scope;
::rlc::ast [Stage:TYPE] TYPE GlobalScope :=
	[Stage; Stage::Name+; ast::[Stage]Global+]Scope;
::rlc::ast [Stage:TYPE] TYPE LocalScope :=
	[Stage; Stage::Name+; ast::[Stage]Local+]Scope;