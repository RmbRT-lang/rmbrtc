INCLUDE "type.rl"
INCLUDE "../resolver/scopeitem.rl"
INCLUDE 'std/hashmap'

::rlc::instantiator
{
	(//
		A specific templated instantiation of a scope item.
		Acts as evaluation context.
	/)
	Instance VIRTUAL
	{
		std::NoCopy; std::NoMove;

		/// The scope item this is an instance of.
		Base: ScopeItem \;
		/// The templates the item was instantiated with.
		Templates: std::[scoper::TemplateDecl #\, TemplateArg #\]NatMap;

		# parent() INLINE Instance * := Base->Parent;

		{
			base: ScopeItem &,
			tpls: TemplateArgs #&
		}
		:	Base(&base)
		{
			origTpls: ?#& := *base.Plan->Templates;
			ASSERT(##tpls <= ##origTpls!);
			FOR(i ::= 0; i < ##tpls; ++i)
				Templates.insert(&origTpls![i], tpls[i]!);
		}

		// Find a template argument.
		template(tpl: scoper::TemplateDecl #\) TemplateArg #*
		{
			IF(t ::= Templates.find(tpl))
				RETURN *t;
			ELSE IF(Base->Parent)
				RETURN Base->Parent->template(tpl);
			ELSE
				RETURN NULL;
		}
	}

	(//
		A scope item in the scope item tree.
		It tracks the various template instantiations of a scope item.
		Only tracks instantiations with the same parent scope item instantiation.
	/)
	ScopeItem
	{
		std::NoCopy; std::NoMove;

		Parent: Instance *;
		Plan: resolver::ScopeItem #\;
		Instances: std::[TemplateArgs, Instance-std::Dynamic]HashMap;

		instance(args: TemplateArgs #&) Instance \
		{
			IF(i ::= Instances.find(args))
				RETURN (*i)!;
			i ::= std::[Instance]new(THIS, args);
			Instances.insert(args, :gc(i));
			RETURN i;
		}

		# root() INLINE BOOL := !Parent;

		# VIRTUAL is_type() BOOL := FALSE;
		# VIRTUAL is_value() BOOL := FALSE;

		<<<
			parent: Instance *,
			resolved: resolver::ScopeItem #\
		>>> ScopeItem \;
	}

	/// Describes a reference to an instance's child.
	InstanceChild
	{
		Parent: Instance *;
		Child: resolver::ScopeItem #\;

		# is_root() INLINE ::= !Parent;

		{};
		{parent: Instance *, child: resolver::ScopeItem #\}: Parent(parent), Child(child);

		THIS==(rhs: InstanceChild #&) INLINE
			::= Parent == rhs.Parent && Child == rhs.Child;
		THIS<(rhs: InstanceChild #&) INLINE
			::= Parent < rhs.Parent
			|| Parent == rhs.Parent && Child < rhs.Child;
	}

	(//
		Contains all instantiated scope items in a program.
		Allows traversing an instance's children.
	/)
	Cache
	{
		ResolverCache: resolver::Cache #\;
		Items: std::[InstanceChild, ScopeItem - std::Dynamic]NatMap;

		{c: resolver::Cache #\}: ResolverCache(c);

		insert(parent: Instance *, child: resolver::ScopeItem #\) ScopeItem *
		{
			desc: InstanceChild(parent, child);
			IF(it ::= THIS[desc])
				RETURN it;
			ELSE
			{
				it := <<<ScopeItem>>>(parent, child);
				ASSERT(Items.insert(desc, :gc(it)));
				RETURN it;
			}
		}

		insert_all_untemplated(
			scope: scoper::Scope #\,
			cache: resolver::Cache #&) VOID
		{ insert_all_untemplated(NULL, scope, cache); }

		/// Insert all untemplated scope items recursivley.
		insert_all_untemplated(
			parent: Instance *,
			scope: scoper::Scope #\,
			cache: resolver::Cache #&
		) VOID
		{
			IF(parent)
				ASSERT(!scope->is_root());
			ELSE
				ASSERT(scope->is_root());

			// If any item exists already, then this scope was inserted already.
			IF(##scope->Items && ##scope->Items.start()!->Items
			&& THIS[(parent, cache.get(scope->Items.start()!->Items[0]!))])
				RETURN;

			FOR(group ::= scope->Items.start(); group; ++group)
				FOR(item ::= group!->Items.start(); item; ++item)
					IF(!item!->Templates)
					{
						it ::= insert(parent, cache.get(item!));
						IF(scope ::= <<scoper::Scope #*>>(item!))
						{
							noTpl: TemplateArgs;
							insert_all_untemplated(it->instance(noTpl), scope, cache);
						}
					}
		}

		/// Retrieve a resolved scope item.
		THIS[i: scoper::ScopeItem #\] INLINE
			::= ResolverCache->get(i);

		/// Retrieve an instantiated scope item if it exists.
		THIS[c: InstanceChild#&] ScopeItem *
		{
			IF(it ::= Items.find(c))
				RETURN *it;
			RETURN NULL;
		}

		/// Retrieve an existing instantiated scope item.
		THIS(c: InstanceChild#&) ScopeItem \
		{
			it ::= Items.find(c);
			ASSERT(it);
			RETURN *it;
		}

		/// Allows iterating over all items.
		# start() INLINE ::= Items.start();
	}

	Scope
	{
		Parent: Instance *;
		Cache: instantiator::Cache \;
		PRIVATE Types: TypeCache \;

		{
			:root,
			cache: instantiator::Cache \
		}:	Parent(NULL),
			Cache(cache);
		
		{
			parent: Instance \,
			cache: instantiator::Cache \
		}:	Parent(parent),
			Cache(cache);

		[T: TYPE] # type(t: T!&&) INLINE ::= (*Types)[<T!&&>(t)];
		[T: TYPE] # THIS[t: T!&&] INLINE ::= (*Cache)[<T!&&>(t)];
		[T: TYPE] # THIS(t: T!&&) INLINE ::= (*Cache)(<T!&&>(t));

		# THIS(item: resolver::ScopeItem #\) INLINE
			::= Cache->insert(Parent, item);
		# THIS(symbol: resolver::Symbol #&) INLINE Symbol
			:= (symbol, THIS);
	}
}