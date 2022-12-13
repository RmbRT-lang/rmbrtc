/// All types that may be resolved into a scope (typedefs, template types, etc.)
::rlc::ast PotentialScope VIRTUAL {}

/// A generic scope. The actual contents of the scope are in specialised scope types for more type safety.
::rlc::ast [Stage: TYPE] ScopeBase VIRTUAL
{
	// This file's parent of this scope.
	Parent: [Stage]ScopeBase *;

	:childOf{p: [Stage]ScopeBase \}: Parent := p;
	:root{}: Parent := NULL;

	# is_root() BOOL INLINE := !Parent;
	# root() [Stage]ScopeBase #\
	{
		p ::= &THIS;
		WHILE(p->Parent)
			p := p->Parent;
		= p;
	}

	#? ABSTRACT scope_item(Stage::Name #&) [Stage]ScopeItem #?*;
	#? ABSTRACT local(Stage::Name #&, LocalPosition) [Stage]ScopeItem #?*;

	/// Returns whether any name was printed.
	# print_name(o: std::io::OStream &) BOOL := print_name_impl(o, NULL);

	PRIVATE # print_name_impl(o: std::io::OStream &, lastOwner: [Stage]ScopeItem #*) BOOL
	{
		owner ::= <<[Stage]ScopeItem #*>>(&THIS);

		printed_parent ::= Parent && Parent->print_name_impl(o, owner ?? owner : lastOwner);

		IF:(ret ::= owner && owner != lastOwner)
		{
			IF(printed_parent)
				std::io::write(o, "::");
			std::io::write(o, owner->Name!++);
		}

		= ret || printed_parent;
	}
}

/// A strongly typed scope.
::rlc::ast [Stage: TYPE; Name: TYPE; Elem: TYPE] Scope -> [Stage]ScopeBase
{
	// This scope's elements coming from this file only.
	Elements: std::[Name #-std::Ref; Elem-std::Dyn]Map;

	std::NoCopy;
	std::NoMove;

	:childOf{parent: [Stage]ScopeBase \} -> (:childOf, parent);
	:root{} -> (:root);

	[Prev: TYPE]
	:transform_virtual{
		p: Prev! #&,
		ctx: Stage::Context+ #&
	} -> (:childOf, ctx.Parent):
		Elements := :reserve(##p.Elements)
	{
		FOR(e ::= p.Elements.start())
			THIS += :make(e!.Value!, ctx.in_parent(&p, &THIS));
	}

	[Prev: TYPE]
	:transform_discrete{
		p: Prev! #&,
		ctx: Stage::Context+ #&
	} -> (:childOf, ctx.Parent):
		Elements := :reserve(##p.Elements)
	{
		FOR(e ::= p.Elements.start())
			THIS += :transform(e!.Value!, ctx.in_parent(&p, &THIS));
	}

	#? start() ? INLINE := Elements.start();
	#? end() ? INLINE := Elements.end();

	# THIS[n: Name#&] Elem *
	{
		IF(e ::= Elements.find(&n))
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

	// v must be a scope item.
	insert(v: Elem-std::Dyn) BOOL
		:= Elements.insert(&<<[Stage]ScopeItem #&>>(v!).Name, &&v);

	THIS += (v: Elem-std::Dyn) BOOL INLINE := insert(&&v);

	#? item(name: Stage::Name #&) [Stage]ScopeItem #?*
	{
		IF(found ::= THIS[name])
			= <<[Stage]ScopeItem #? \>>(found);
		= NULL;
	}
}

::rlc::ast [Stage:TYPE] MemberScope -> [Stage; Stage::Name+; ast::[Stage]Member+]Scope
{
	:childOf{parent: [Stage]ScopeBase \} -> (:childOf, parent);

	[Prev: TYPE]
	:transform_virtual{
		p: Prev! #&,
		ctx: Stage::Context+ #&
	} -> (:transform_virtual, p, ctx);

	[Prev: TYPE]
	:transform_discrete{
		p: Prev! #&,
		ctx: Stage::Context+ #&
	} -> (:transform_discrete, p, ctx);


	#? FINAL scope_item(name: Stage::Name #&) [Stage]ScopeItem #? *
		:= >>THIS[name];
	#? FINAL local(name: Stage::Name #&, LocalPosition) [Stage]ScopeItem #? *
		:= scope_item(name);
}

::rlc::ast [Stage:TYPE] GlobalScope -> [Stage; Stage::Name+; ast::[Stage]Global+]Scope
{
	:root{} -> (:root);
	:childOf{parent: [Stage]ScopeBase \} -> (:childOf, parent);

	[Prev: TYPE]
	:transform_virtual{
		p: Prev! #&,
		ctx: Stage::Context+ #&
	} -> (:transform_virtual, p, ctx);

	[Prev: TYPE]
	:transform_discrete{
		p: Prev! #&,
		ctx: Stage::Context+ #&
	} -> (:transform_discrete, p, ctx);

	#? FINAL scope_item(name: Stage::Name #&) [Stage]ScopeItem #? *
		:= >>THIS[name];
	#? FINAL local(name: Stage::Name #&, LocalPosition) [Stage]ScopeItem #? *
		:= scope_item(name);
}

::rlc::ast [Stage:TYPE] LocalScope -> [Stage; Stage::Name+; ast::[Stage]Local+]Scope
{
	:childOf{parent: [Stage]ScopeBase \} -> (:childOf, parent);

	[Prev: TYPE]
	:transform_virtual{
		p: Prev! #&,
		ctx: Stage::Context+ #&
	} -> (:transform_virtual, p, ctx);

	[Prev: TYPE]
	:transform_discrete{
		p: Prev! #&,
		ctx: Stage::Context+ #&
	} -> (:transform_discrete, p, ctx);


	#? FINAL scope_item(name: Stage::Name #&) [Stage]ScopeItem #? * := NULL;
	#? FINAL local(name: Stage::Name #&, pos: LocalPosition) [Stage]ScopeItem #? *
	{
		IF(local ::= THIS[name])
			IF(local->Position <= pos)
				= local;
		= NULL;
	}
}