INCLUDE "../resolver/symbol.rl"
INCLUDE "templates.rl"

::rlc::instantiator Symbol
{
	UNION Resolved
	{
		(// A template argument. /)
		Template: TemplateArg #\;
		(// A fully resolved scopeitem instance. /)
		Reference: Instance *;
		(// The inner-most resolved item group. /)
		Group: scoper::detail::ScopeItemGroup #\;
		(// Built-in or non-plain types. /)
		Type: instantiator::Type #\;
	}

	Unresolved
	{
		Trail: scoper::Symbol::Child# - std::Buffer;
		Templates: resolver::TemplateArgs# - std::Buffer;

		# <BOOL> INLINE := !Trail;

		{};
		{from: resolver::Symbol::Unresolved}:
			Trail(from.Symbols),
			Templates(from.Templates!)
		{
			ASSERT(##Trail == ##Templates);
		}
	}

	HeadType: CHAR #*;
	Head: Resolved;
	HeadSymbol: scoper::Symbol::Child #*;
	Rest: Unresolved;
	GroupTemplates: resolver::TemplateArg# - std::Buffer;

	# type(scope: Scope #&) Type #\
	{
		IF(HeadType == TYPE TYPE(Instance))
			TYPE SWITCH(Head.Reference->Base->Plan)
			{
			resolver::Class, resolver::Rawtype, resolver::Union:
				RETURN scope.type(<CustomType>(Head.Reference));
			DEFAULT: THROW <Error>(:notAType, HeadSymbol);
			}
		ELSE IF(HeadType == TYPE TYPE(instantiator::Type))
			RETURN Head.Type;

		THROW <Error>(:notAType, HeadSymbol);
	}

	# instance() Instance \
	{
		IF(HeadType == TYPE TYPE(Instance))
			RETURN Head.Reference;
		ELSE IF(HeadType == TYPE TYPE(instantiator::Type))
			IF(desired ::= <<CustomType #\>>(Head.Type))
				RETURN desired->Definition;

		THROW <Error>(:notAScopeItem, HeadSymbol);
	}

	{
		symbol: resolver::Symbol #&,
		scope: Scope #&
	}:
		HeadType(NULL),
		Rest(symbol.Rest)
	{
		// Resolve head properly.
		IF(symbol.IsTemplate)
			resolve_template_head(symbol, scope);
		ELSE
			resolve_instance_head(symbol, scope);
	}

	# resolved() INLINE ::= !Rest;

	# has_head() INLINE ::= HeadType != NULL;
	# head_is_template() INLINE ::= HeadType == TYPE TYPE(TemplateArg);
	# head_is_reference() INLINE ::= HeadType == TYPE TYPE(Instance);

	ENUM ResolveFailure
	{
		notFound,
		builtinParent,
		notAType,
		notAScopeItem
	}

	Error -> scoper::Error
	{
		Reason: ResolveFailure;
		Child: scoper::Symbol::Child #\;

		{
			reason: ResolveFailure,
			child: scoper::Symbol::Child #\
		}
		->	scoper::Error(child->Position)
		:	Reason(reason),
			Child(child);

		# OVERRIDE print_msg(o: std::io::OStream &) VOID
		{
			o.write_all("cannot resolve member '", Child->Name, "': ");
			SWITCH(Reason)
			{
			:notAType:
				o.write("expected to be a type");
			:notFound:
				o.write("no such member");
			:builtinParent:
				o.write("parent is a builtin primitive type");
			:notAScopeItem:
				o.write("expected to be a scope item");
			}
		}
	}

	PRIVATE resolve_template_head(
		symbol: resolver::Symbol#&,
		scope: Scope #&
	) VOID
	{
		HeadType := TYPE TYPE(TemplateArg);
		tpl ::= scope.Parent->template(symbol.Item.TemplateArg);
		ASSERT(tpl && "template should have been resolved");
		ASSERT(!symbol.Trail && "templates cannot have a symbol trail");
		Head.Template := tpl;
	}

	PRIVATE resolve_instance_head(
		symbol: resolver::Symbol#&,
		scope: Scope #&
	) VOID
	{
		HeadType := TYPE TYPE(Instance);

		symPath# ::= get_resolved_path(symbol, scope);
		ctxPath# ::= get_context_path(scope.Parent);
		rootLen# ::= get_common_root(symPath!, ctxPath!);
		root# ::= ctxPath!.cut(rootLen);
		unspec# ::= root.cut(##symPath - ##symbol.Trail.Templates);
		spec# ::= symPath!.cut_start(##symbol.Trail.Templates);
		ASSERT(##spec + ##unspec == ##symPath);

		// Inherit unspecified template arguments from context by reusing the
		// context's root.
		Head.Reference := unspec ? unspec.back() : NULL;

		// Inherit all specified template arguments from the symbol.
		FOR(i ::= 0; i < ##spec; i++)
		{
			base ::= scope.Cache->insert(Head.Reference, spec[:ok(i)]);
			tpls: TemplateArg - std::DynVector;
			tpls.reserve(##symbol.Trail.Templates[i]);
			FOR(tpl ::= symbol.Trail.Templates[i].start(); tpl; ++tpl)
				tpls += :gc(<<<TemplateArg>>>(tpl!, scope));

			Head.Reference := base->instance(tpls);
		}

		// Select a specific overload if possible, resolve typedefs.
		items ::= symbol.Item.ItemGroup->Items!;
	}

	resolve_item(
		group: scoper::detail::ScopeItemGroup #\,
		templates: resolver::TemplateArgs#&,
		scope: Scope #&
	) VOID
	{
		items ::= group->Items!;
		TYPE SWITCH(items[0]!)
		{
		scoper::Function:
			{
				HeadType := TYPE TYPE(scoper::detail::ScopeItemGroup);
				Head.Group := group;
			}
		scoper::Typedef:
			{
				ASSERT(1 == ##items);
				base ::= scope.Cache->insert(Head.Reference, scope[items.front()!]);
				tpls: TemplateArgs;
				tpls.reserve(##templates);
				FOR(it ::= templates!.start(); it; ++it)
					tpls += <<<TemplateArg>>>(it!, scope);
				inst ::= base->instance(tpls);
				resolved ::= scope[items.front()!];
				typeBase ::= <<resolver::Typedef #\>>(resolved)->Type!;
				// type resolve from resolver (type, inst - templates).
				type ::= <<<Type>>>(typeBase, scope);
				IF(custom ::= <<CustomType #*>>(type))
				{
					HeadType := TYPE TYPE(Instance);
					Head.Reference := custom->Definition;
				}
				ELSE
				{
					HeadType := TYPE TYPE(Type);
					Head.Type := type;
				}
			}
		DEFAULT:
			{
				ASSERT(!Rest);
				ASSERT(1 == ##items);
				HeadType := TYPE TYPE(Instance);
				base ::= scope.Cache->insert(Head.Reference, scope[items.front()!]);
				tpls: TemplateArgs;
				tpls.reserve(##templates);
				FOR(it ::= templates!.start(); it; ++it)
					tpls += <<<TemplateArg>>>(it!, scope);
				Head.Reference := base->instance(tpls);
			}
		}
	}

	PRIVATE STATIC get_resolved_path(
		symbol: resolver::Symbol#&,
		scope: Scope#&
	) resolver::ScopeItem #\ - std::Vector
	{
		sym: resolver::ScopeItem #\ - std::Vector;
		FOR(parent ::= symbol.Trail.Tail;
			parent;
			parent := <<scoper::ScopeItem #\>>(parent->parent()))
			sym += (:at(0), scope[parent]);
		RETURN &&sym;
	}

	PRIVATE STATIC get_context_path(
		context: Instance #\
	) Instance \ - std::Vector
	{
		ctxPath: Instance \-std::Vector;
		FOR(ctx ::= context; ctx; ctx := ctx->parent())
			ctxPath += (:at(0), ctx);
		RETURN &&ctxPath;
	}

	PRIVATE STATIC get_common_root(
		symbol: resolver::ScopeItem #\ - std::Buffer#&,
		context: Instance \ - std::Buffer#&
	) UM
	{
		itSym ::= symbol.start();
		itCtx ::= context.start();
		rootLen ::= 0;
		// Symbol paths have a common root. Find the end of the root.
		WHILE(itSym && itCtx && itSym! == itCtx!->Base->Plan)
		{
			++itSym;
			++itCtx;
			++rootLen;
		}
		RETURN rootLen;
	}

	(/PRIVATE STATIC convert_template_arg_to_instance(t: TemplateArg) Instance \
	{
	}/)
}