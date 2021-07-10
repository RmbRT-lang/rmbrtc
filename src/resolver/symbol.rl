INCLUDE "../scoper/symbol.rl"
INCLUDE "../scoper/error.rl"

INCLUDE "templates.rl"

INCLUDE 'std/error'
INCLUDE 'std/err/unimplemented'
INCLUDE 'std/io/format'
INCLUDE "../scoper/fileregistry.rl"

(//
	Potentially half-resolved symbol type (due to accessing templates). Only resolves into a scope item group, and a group element has to be selected upon use based on context.

	A symbol only contains the tail nodes of a symbol's scope path, and any missing outer path nodes are to be substituted based on context, up to the root scope.

	A symbol is a collection of (outer, symbol, inner)
/)
::rlc::resolver Symbol
{
	(// Explicitly stated parent nodes of the resolved item. /)
	Resolved
	{
		(// Inner-most resolved item. /)
		Tail: scoper::ScopeItem # *;
		(// All specified path nodes' templates. /)
		Templates: TemplateArg - std::Dynamic - std::Vector - std::Vector;

		{
			scope: scoper::Scope # *,
			tail: scoper::ScopeItem # *,
			symbol: scoper::Symbol #&,
			depth: UM
		}:	Tail(tail)
		{
			FOR(i ::= 0; i+1 < depth; i++)
			{
				child # ::= &symbol.Children[i];
				templates: TemplateArg - std::Dynamic - std::Vector;
				FOR(tpl ::= child->Templates.start(); tpl; ++tpl)
					templates += :gc(TemplateArg::create(scope, *tpl));
				Templates += &&templates;
			}
		}

		(// The amount of resolved items. /)
		# depth() INLINE UM := ##Templates;
	}
	(// A typedef's or template place-holder's referenced children. /)
	Unresolved
	{
		Symbols: scoper::Symbol::Child # - std::Buffer;
		Templates: TemplateArg - std::Dynamic - std::Vector - std::Vector;

		{
			scope: scoper::Scope #\,
			symbol: scoper::Symbol #&,
			resolved: UM
		}:	Symbols(symbol.Children.content().drop_start(resolved))
		{
			FOR(child ::= Symbols.start(); child; ++child)
			{
				templates: TemplateArg - std::Dynamic - std::Vector;
				FOR(tpl ::= child->Templates.start(); tpl; ++tpl)
					templates += :gc(TemplateArg::create(scope, *tpl));
				Templates += &&templates;
			}
		}
	}

	(// A reference to a specific code entity, either a scope item or template place-holder. /)
	UNION Reference
	{
		TemplateArg: scoper::TemplateDecl #\;
		ItemGroup: scoper::detail::ScopeItemGroup #\;
	}

	(// The resolved parents of `Item`. /)
	Trail: Resolved;

	(// Whether the resolved item is a template argument or scope item. /)
	IsTemplate: BOOL;
	(// The inner-most resolvable part of the symbol. /)
	Item: Reference;
	(// Templates of `Item`. /)
	ItemTemplates: TemplateArg - std::Dynamic - std::Vector;

	(// Symbol children depending on an uninstantiated template or typedef. /)
	Rest: Unresolved;

	{
		:resolve,
		scope: scoper::Scope #&,
		reference: scoper::Symbol #&
	}->	Symbol(resolve(scope, reference));

	{
		:resolve,
		scope: scoper::Scope #&,
		reference: scoper::Symbol #&,
		position: UM
	}->	Symbol(resolve(scope, reference, position));

	NotResolved -> scoper::Error
	{
		Scope: scoper::Scope #\;
		Name: scoper::String;
		ParentName: scoper::String;
		Number: UM;
		Reason: CHAR #\;

		{
			scope: scoper::Scope #\,
			name: scoper::String #&,
			pos: src::Position #&,
			reason: CHAR #\
		}->	scoper::Error(pos)
		:	Scope(scope),
			Name(name),
			Reason(reason),
			Number(0);

		{
			scope: scoper::Scope #\,
			name: scoper::String #&,
			pos: src::Position #&,
			reason: CHAR #\,
			number: UM
		}->	scoper::Error(pos)
		:	Scope(scope),
			Name(name),
			Reason(reason),
			Number(number+1);

		{
			scope: scoper::Scope #\,
			parentName: scoper::String #&,
			name: scoper::String #&,
			pos: src::Position #&,
			reason: CHAR #\
		}->	scoper::Error(pos)
		:	Scope(scope),
			ParentName(parentName),
			Name(name),
			Reason(reason),
			Number(0);

		# OVERRIDE print_msg(
			o: std::io::OStream &) VOID
		{
			o.write_all("Resolving ", Name, " in ");
			
			IF(Scope->is_root())
				o.write("global scope");
			ELSE
				Scope->print_name(o);
			IF(ParentName)
				o.write_all("::", ParentName);
			
			o.write(" failed");
			IF(Reason)
				o.write_all(": ", Reason);
			IF(Number)
			{
				o.write("(template #");
				std::io::format::dec(o, Number);
				o.write(")");
			}
			o.write(".");
		}
	}

	STATIC resolve(
		scope: scoper::Scope #&,
		reference: scoper::Symbol #&
	) Symbol := resolve(scope, reference, 0);

	STATIC resolve(
		scope: scoper::Scope #&,
		reference: scoper::Symbol #&,
		position: UM
	) Symbol
	{
		(/
		The symbol itself is resolved either relative to the current scope or to the root scope, while the template arguments are resolved independently.
		/)
		symbolScope: scoper::Scope #\ := reference.IsRoot
			? scope.root()
			: &scope;
		ASSERT(symbolScope);

		// The inner-most item that could be resolved.
		itemGroup: scoper::detail::ScopeItemGroup #* := NULL;
		// The parent of the inner-most resolved item, if part of the symbol.
		trail: scoper::ScopeItem #* := NULL;

		FOR(i ::= 0; i < ##reference.Children; i++)
		{
			origSymScope # ::= symbolScope;
			ASSERT(reference.Children[i].Name.Size != 123);
			oldItemGroup ::= itemGroup;

			// Try to resolve scope item within scope.
			itemGroup := symbolScope->find(reference.Children[i].Name);


			(/
			If we found no item within the scope, and this is the first symbol child, look for template place-holders in the current scope or search the parent scope. Only non-root symbols can address template place-holders.
			/)
			IF(!i
			&& !is_match(itemGroup, position, 0, reference)
			&& !reference.IsRoot
			&& symbolScope->Parent)
			{
				name ::= reference.Children[0].Name;
				DO()
				{
					IF(symbolScope->Owner
					&& symbolScope->Owner->owner_type() == :scopeItem)
					{
						item ::= <<scoper::ScopeItem #\>>(symbolScope->Owner);
						IF(decl ::= item->Templates.find(name))
							IF(reference.Children[0].Templates)
								THROW <NotResolved>(
									symbolScope,
									name,
									reference.Children[0].Position,
									"template arguments must not have templates");
							ELSE
								RETURN (symbolScope, decl, &reference);

					}
					symbolScope := symbolScope->Parent;
					IF(itemGroup := symbolScope->find(name))
						IF(!is_match(itemGroup, position, 0, reference))
							itemGroup := NULL;
				} WHILE(!itemGroup && symbolScope->Parent)
			}
			IF(!itemGroup)
				THROW <NotResolved>(
					origSymScope,
					reference.Children[i].Name,
					reference.Children[i].Position,
					"not found");

			IF(!is_match(itemGroup, position, i, reference))
				THROW <NotResolved>(
					origSymScope,
					reference.Children[i].Name,
					reference.Children[i].Position,
					"not a suitable candidate");

			IF(<<scoper::LocalVariable #\>>(&*itemGroup->Items[0]))
			{
				IF(reference.Children[i].Templates)
					THROW <NotResolved>(
						itemGroup->Scope,
						itemGroup->Name,
						reference.Children[i].Position,
						"variables must not have templates");
			}

			(/
			If there are more symbol children, then the item we have found must be unique so we can progress. Also check whether it is a typedef, in which case resolving stops early.
			/)
			IF(i != ##reference.Children - 1)
			{
				child # ::= &reference.Children[i];
				IF(##itemGroup->Items > 1)
					THROW <NotResolved>(
						symbolScope,
						child->Name,
						child->Position,
						"ambiguous");

				item # ::= &*itemGroup->Items[0];

				// Check template argument count.
				IF(##child->Templates > ##item->Templates)
					THROW <NotResolved>(
						symbolScope,
						child->Name,
						child->Position,
						"too many template arguments");

				// Check template argument kind compatibility (value/type). Ignore empty and omitted template arguments
				FOR(j ::= 0; j < ##child->Templates; j++)
					IF(child->Templates[j])
						SWITCH(type ::= item->Templates.Templates[j].Type)
						{
						CASE :number, :value:
							IF(!child->Templates[j][0].is_expression())
								THROW <NotResolved>(
									symbolScope,
									child->Name,
									child->Position,
									"expression expected as template argument", j);
						CASE :type:
							IF(!child->Templates[j][0].is_type())
								THROW <NotResolved>(
									symbolScope,
									child->Name,
									child->Position,
									"type expected as template argument", j);
						DEFAULT:
							THROW <std::err::Unimplemented>(type.NAME());
						}

				oldSymbolScope # ::= symbolScope;
				isValidParent: BOOL;
				(symbolScope, isValidParent) := primaryScope(item);
				// Is it a candidate for having children?
				IF(!isValidParent)
					THROW <NotResolved>(
		 				oldSymbolScope,
						child->Name,
						reference.Children[i+1].Name,
						reference.Children[i+1].Position,
						"parent cannot have children");
				ELSE IF(!symbolScope) // Typedefs cannot be resolved further.
					RETURN <Symbol>(trail, &scope, itemGroup, &reference, i+1);

				// Remember as parent of next iteration.
				trail := item;
			}
		}

		IF(##itemGroup->Items == 1)
		{
			child # ::= &reference.Children.back();
			item # ::= &*itemGroup->Items[0];

			// Check template argument count.
			IF(##child->Templates > ##item->Templates)
				THROW <NotResolved>(
					symbolScope,
					child->Name,
					child->Position,
					"number of template arguments does not match declaration");

			// Check template argument kind compatibility (value/type). Ignore empty and omitted template arguments
			FOR(j ::= 0; j < ##child->Templates; j++)
				IF(child->Templates[j])
					SWITCH(type ::= item->Templates.Templates[j].Type)
					{
					CASE :number, :value:
						IF(!child->Templates[j][0].is_expression())
							THROW <NotResolved>(
								symbolScope,
								child->Name,
								child->Position,
								"expression expected as template argument", j);
					CASE :type:
						IF(!child->Templates[j][0].is_type())
							THROW <NotResolved>(
								symbolScope,
								child->Name,
								child->Position,
								"type expected as template argument", j);
					DEFAULT:
						THROW <std::err::Unimplemented>(type.NAME());
					}
		}

		RETURN <Symbol>(trail, &scope, itemGroup, &reference);
	}

	STATIC is_match(
		itemGroup: scoper::detail::ScopeItemGroup #*,
		position: UM,
		index: UM,
		symbol: scoper::Symbol #&
	) BOOL
	{
		IF(!itemGroup)
			RETURN FALSE;

		item # ::= &*itemGroup->Items[0];
		IF(index == ##symbol.Children-1)
		{
			SWITCH(type ::= item->type())
			{
			CASE :variable:
				{
					IF(var ::= <<scoper::LocalVariable #\>>(item))
						IF(var->Position <= position)
							RETURN TRUE;
					RETURN TRUE;
				}
			CASE :function, :externSymbol:
				RETURN TRUE;
			}
		}

		SWITCH(type ::= item->type())
		{
		CASE
			:variable,
			:function,
			:externSymbol:
			RETURN FALSE;
		}

		RETURN TRUE;
	}
	(//
		Returns the primary scope of a scope item, if it has one.
	/)
	STATIC primaryScope(item: scoper::ScopeItem #\) {scoper::Scope #*, BOOL}
	{
		SWITCH(type ::= item->type())
		{
		DEFAULT:
			THROW <std::err::Unimplemented>(type.NAME());
		CASE :class:
			RETURN (<scoper::Class #\>(item), TRUE);
		CASE :rawtype:
			RETURN (<scoper::Rawtype #\>(item), TRUE);
		CASE :union:
			RETURN (<scoper::Union #\>(item), TRUE);
		CASE :enum:
			RETURN (<scoper::Enum #\>(item), TRUE);
		CASE :namespace:
			RETURN (<scoper::Namespace #\>(item), TRUE);
		CASE :mask:
			RETURN (<scoper::Mask #\>(item), TRUE);
		CASE :typedef:
			RETURN (NULL, TRUE);
		CASE :variable, :enumConstant, :function, :externSymbol:
			RETURN (NULL, FALSE);
		}
	}

	(// Creates a fully resolved symbol. /)
	{
		parent: scoper::ScopeItem #*,
		origScope: scoper::Scope #\,
		itemGroup: scoper::detail::ScopeItemGroup #\,
		symbol: scoper::Symbol #\
	}->	Symbol(parent, origScope, itemGroup, symbol, ##symbol->Children);

	(// Creates a partially resolved symbol.
	@param resolved:
		The number of resolved symbol children. /)
	{
		parent: scoper::ScopeItem #*,
		origScope: scoper::Scope #\,
		group: scoper::detail::ScopeItemGroup #\,
		symbol: scoper::Symbol #\,
		resolved: UM
	}:	IsTemplate(FALSE),
		Trail(origScope, parent, *symbol, resolved),
		Rest(group->Scope, *symbol, resolved)
	{
		Item.ItemGroup := group;
	}

	(// Creates a symbol resolving to a template argument. /)
	{
		scope: scoper::Scope #\,
		template: scoper::TemplateDecl #\,
		symbol: scoper::Symbol #\
	}:	IsTemplate(TRUE),
		Trail(NULL, NULL, *symbol, 1),
		Rest(scope, *symbol, 1)
	{
		Item.TemplateArg := template;
	}
}