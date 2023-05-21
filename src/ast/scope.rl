/// All types that may be resolved into a scope (typedefs, template types, etc.)
::rlc::ast PotentialScope VIRTUAL {}

/// A generic scope. The actual contents of the scope are in specialised scope types for more type safety.
::rlc::ast [Stage: TYPE] ScopeBase VIRTUAL
{
	// This file's parent of this scope.
	Parent: [Stage]ScopeBase \-std::Opt;

	_1: std::NoMove -std::Opt;
	_2: std::NoCopy -std::Opt;

	{BARE}: Parent := NULL, _1 := NULL, _2 := NULL { ASSERT(!_1); ASSERT(!_2); }
	:childOf{p: [Stage]ScopeBase \-std::Opt}: Parent := p, _1(:a),_2(:a) { ASSERT(Parent); }
	:root{}: Parent := NULL, _1(:a),_2(:a);

	# is_root() BOOL INLINE := !Parent;
	# root() [Stage]ScopeBase #\
	{
		p ::= &THIS;
		WHILE(p->Parent)
			p := p->Parent!;
		= p;
	}

	# ABSTRACT scope_item(Stage::Name #&) [Stage]ScopeItem #*;
	# ABSTRACT local(Stage::Name #&, LocalPosition) [Stage]ScopeItem #*;

	/// Returns whether any name was printed.
	# print_name(o: std::io::OStream &) BOOL {
		= print_name_impl(o, NULL);
	}

	PRIVATE # print_name_impl(o: std::io::OStream &, lastOwner: [Stage]ScopeItem #*) BOOL
	{
		owner ::= <<[Stage]ScopeItem #*>>(&THIS);

		printed_parent ::= Parent && Parent!->print_name_impl(o, owner ?? owner : lastOwner);

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
::rlc::ast [Stage: TYPE; Name: TYPE; Elem: TYPE] Scope VIRTUAL -> [Stage]ScopeBase
{
	// This scope's elements coming from this file only.
	Elements: std::[Name #-std::Ref; Elem-std::Val]Map;

	:childOf{parent: [Stage]ScopeBase \-std::Opt} -> (:childOf, parent);
	:root{} -> (:root);

	[Prev: TYPE]
	:transform_virtual{
		p: Prev! #&,
		ctx: Stage::Context+ #&
	} -> (:childOf, ctx.Parent):
		Elements := :reserve(##p.Elements)
	{
		_ctx ::= ctx.in_parent(&p, &THIS);
		FOR(e ::= p.Elements.start())
			insert_or_merge(e!.Key, e!.Value!, _ctx);
	}

	#? start() ? INLINE := Elements.start();
	#? end() ? INLINE := Elements.end();

	# THIS[n: Name#&] Elem #*
	{
		IF(e ::= Elements.find(&n))
			= *e;
		= NULL;
	}
	# ##THIS UM INLINE := ##Elements;

	[Prev: TYPE]
	insert_or_merge(
		name: Stage::Prev::Name+ #&,
		p: Prev! #&,
		ctx: Stage::Context #&
	) VOID
	{
		eName ::= ctx.transform_name(name);
		IF:!(existing ::= Elements.find(&eName))
		{
			THIS += :make(>>p, ctx);
			RETURN;
		}
		existItem ::= <<[Stage]ScopeItem \>>(existing->mut_ptr());
		eItem :?&:= <<[Stage::Prev+]ScopeItem #&>>(p);
		IF:!(mergeable ::= <<[Stage]MergeableScopeItem *>>(existItem))
			THROW <MergeError>(existItem, &eItem);
		IF:!(prevMergeable ::= <<[Stage::Prev+]MergeableScopeItem #*>>(&eItem))
			THROW <MergeError>(existItem, &eItem);

		ctx.extend_with(*mergeable, *prevMergeable);
	}

	/// v must be a scope item.
	insert(v: Elem-std::Val) VOID
	{
		ASSERT( Elements.insert(&<<[Stage]ScopeItem #&>>(v!).Name, &&v) );
	}

	THIS += (v: Elem-std::Val) VOID INLINE := insert(&&v);

	# item(name: Stage::Name #&) [Stage]ScopeItem #*
	{
		IF(found ::= THIS[name])
			= >>found;
		= NULL;
	}
}

::rlc::ast [Stage:TYPE] MemberScope -> [Stage; Stage::Name+; ast::[Stage]Member+]Scope
{
	:childOf{parent: [Stage]ScopeBase \-std::Opt} -> (:childOf, parent);

	[Prev: TYPE]
	:transform_virtual{
		p: Prev! #&,
		ctx: Stage::Context+ #&
	} -> (:transform_virtual, p, ctx);

	# FINAL scope_item(name: Stage::Name #&) [Stage]ScopeItem #*
		:= >>THIS[name];
	# FINAL local(name: Stage::Name #&, LocalPosition) [Stage]ScopeItem #*
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

	# FINAL scope_item(name: Stage::Name #&) [Stage]ScopeItem #*
		:= >>THIS[name];
	# FINAL local(name: Stage::Name #&, LocalPosition) [Stage]ScopeItem #*
		:= scope_item(name);
}

::rlc::ast [Stage:TYPE] LocalScope -> [Stage; Stage::Name+; ast::[Stage]Local+]Scope
{
	:childOf{parent: [Stage]ScopeBase \-std::Opt} -> (:childOf, parent);

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


	# FINAL scope_item(name: Stage::Name #&) [Stage]ScopeItem #* := NULL;
	# FINAL local(name: Stage::Name #&, pos: LocalPosition) [Stage]ScopeItem #*
	{
		IF(local ::= THIS[name])
			IF(local->Position <= pos)
				= >>local;
		= NULL;
	}
}

::rlc::ast [Stage:TYPE] ArgScope -> [Stage]ScopeBase
{
	Args: [Stage]TypeOrArgument - std::ValVec;

	:childOf{
		parent: [Stage]ScopeBase \-std::Opt
	} -> (:childOf, parent);

	{args: [Stage]TypeOrArgument - std::ValVec &&} -> (:root): Args := &&args;

	:transform{
		p: [Stage::Prev+]ArgScope #&,
		ctx: Stage::Context+ #&
	} -> (:childOf, ctx.Parent):
		Args := :reserve(##p.Args)
	{
		_ctx ::= ctx.in_parent(&p, &THIS);
		FOR(arg ::= p.Args.start())
			THIS += :make(arg!, _ctx);
	}

	THIS += (arg: [Stage]TypeOrArgument - std::Val) VOID
	{
		IF(argItem ::= <<[Stage]ScopeItem #*>>(arg))
			IF(old ::= local(argItem->Name, 0))
				IF(argItem->Name == old->Name)
					THROW <MergeError>(old, argItem);
		Args += &&arg;
	}

	# at(i: std::Index) [Stage]TypeOrArgument #* INLINE := Args[i].ptr();
	# ## THIS UM := ##Args;

	# FINAL scope_item(name: Stage::Name #&) [Stage]ScopeItem #* := NULL;
	# FINAL local(name: Stage::Name #&, pos: LocalPosition) [Stage]ScopeItem #*
	{
		FOR(arg ::= Args.start())
			IF(argItem ::= <<[Stage]ScopeItem #*>>(&arg!))
				IF(argItem->Name == name)
					= argItem;
		= NULL;
	}
}

::rlc::ast [Stage: TYPE; T: TYPE] Scoped -> [Stage]ScopeBase, T
{
	PRIVATE #? item() ? INLINE := <<[Stage]ScopeItem #? \>>(&THIS);

	[Prev: TYPE]
	:transform{
		p: Prev! #&,
		ctx: Stage::Context+ #&
	} -> (:childOf, ctx.Parent), (:transform, p, ctx);

	# FINAL scope_item(name: Stage::Name #&) [Stage]ScopeItem #*
		:= THIS.item()->Name <> name ??  NULL : THIS.item();
	# FINAL local(name: Stage::Name #&, LocalPosition) [Stage]ScopeItem #*
		:= scope_item(name);
}

::rlc::ast [Stage: TYPE; T: TYPE] OptScoped -> [Stage]ScopeBase, std::[T]Opt
{
	PRIVATE #? item() ? INLINE := <<[Stage]ScopeItem #? \>>(&THIS.ok());

	[Prev: TYPE]
	:transform{
		p: Prev! #&,
		ctx: Stage::Context+ #&
	} -> (:childOf, ctx.Parent), (:if, p, :transform(p.ok(), ctx));

	# FINAL scope_item(name: Stage::Name #&) [Stage]ScopeItem #*
		:= THIS ?? THIS.item()->Name <> name ??  NULL : THIS.item() : NULL;
	# FINAL local(name: Stage::Name #&, LocalPosition) [Stage]ScopeItem #*
		:= scope_item(name);
}

::rlc::ast [Stage: TYPE; T: TYPE] 
ValScoped -> [Stage]ScopeBase, std::[T]Val
{
	PRIVATE # item() ? INLINE := <<[Stage]ScopeItem #*>>(THIS.ptr());
	PRIVATE item_mut() ? INLINE := <<[Stage]ScopeItem *>>(THIS.mut_ptr());

	:parsed{v: std::[T]Val &&} -> (BARE), (&&v);

	[Prev: TYPE]
	:a{
		p: Prev! #&,
		ctx: Stage::Context+ #&
	} -> (:childOf, ctx.Parent), (:a, :transform(p!, ctx));

	[Prev: TYPE]
	:make{
		p: Prev! #&,
		ctx: Stage::Context+ #&
	} -> (:childOf, ctx.Parent), (:make, p!, ctx);

	# FINAL scope_item(name: Stage::Name #&) [Stage]ScopeItem #*
		:= THIS.item() && THIS.item()->Name == name ?? THIS.item() : NULL;
	# FINAL local(name: Stage::Name #&, LocalPosition) [Stage]ScopeItem #*
		:= scope_item(name);
}

::rlc::ast [Stage: TYPE; T: TYPE] ValOptScoped -> [Stage]ScopeBase, std::[T]ValOpt
{
	PRIVATE #? item() ? INLINE := <<[Stage]ScopeItem #? *>>(THIS.ptr());

	:parsed{v: std::[T]ValOpt &&} -> (BARE), (&&v);

	[Prev: TYPE]
	:if{
		p: Prev! #&,
		ctx: Stage::Context+ #&
	} -> (:childOf, ctx.Parent), (:if, p, :transform(p.ok(), ctx));

	[Prev: TYPE]
	:make_if{
		p: Prev! #&,
		ctx: Stage::Context+ #&
	} -> (:childOf, ctx.Parent), (:make_if, p, p.ok(), ctx);

	# FINAL scope_item(name: Stage::Name #&) [Stage]ScopeItem #*
		:= THIS.item() && THIS.item()->Name == name ?? THIS.item() : NULL;
	# FINAL local(name: Stage::Name #&, LocalPosition) [Stage]ScopeItem #*
		:= scope_item(name);
}