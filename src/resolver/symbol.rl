INCLUDE "../ast/symbol.rl"

INCLUDE 'std/io/streamutil'

(//
	Potentially half-resolved symbol type (due to accessing templates). Only resolves into a scope item group, and a group element has to be selected upon use based on context.

	A symbol only contains the tail nodes of a symbol's scope path, and any missing outer path nodes are to be substituted based on context, up to the root scope.

	A symbol is a collection of (outer, symbol, inner)
/)
::rlc::resolver Symbol
{
	(// A typedef's or template place-holder's referenced children. /)
	Unresolved
	{
		Symbols: scoper::Config::Symbol::Child # - std::Buffer;
		Templates: ast::[Config]TemplateArg - std::Vec - std::Vec;

		{};

		{
			symbol: ast::[scoper::Config]Symbol #&,
			resolved: UINT,
			templates: ast::[Config]TemplateArg -std::Vec -std::Buffer
		}:
			Symbols := symbol.Children!.drop_start(resolved)++,
			Templates := :reserve(##templates - resolved)
		{
			FOR(i ::= 0; i < ##Templates; i++)
				Templates[i] := &&templates[resolved + i];
		}
	}

	(// The resolved parents of `Item`. /)
	AncestorTemplates: ast::[Config]TemplateArg - std::Vec - std::Vec;

	(// The inner-most resolvable part of the symbol. /)
	Item: ast::[scoper::Config]ScopeItem #\;
	(// Templates of `Item`. /)
	ItemTemplates: ast::[Config]TemplateArg - std::Vec;

	(// Symbol children depending on an uninstantiated template or typedef. /)
	Rest: Unresolved;

	:resolve{
		reference: ast::[scoper::Config]Symbol #&,
		ctx: Context #&
	} := resolve(reference, ctx);

	:resolve_local{
		reference: ast::[scoper::Config]Symbol #&,
		position: ast::LocalPosition,
		ctx: Context #&
	} := resolve_local(reference, position, ctx);


	STATIC resolve(
		reference: ast::[scoper::Config]Symbol #&,
		ctx: Context #&
	) Symbol := resolve_local(reference, 0, ctx);

	STATIC resolve_local(
		reference: ast::[scoper::Config]Symbol #&,
		position: ast::LocalPosition,
		ctx: Context #&
	) Symbol
	{
		/// Resolve all template arguments.
		child_templates: ast::[Config]TemplateArg -std::Vec -std::Vec;
		FOR(child ::= reference.Children.start().ok())
			child_templates += ast::[Config]transform_template_args(child!.Templates!++, ctx);

		/// Resolve the first symbol child.
		symbolScope ::= ctx.PrevParent;
		IF(reference.IsRoot)
			symbolScope := symbolScope->root();

		IF:!(item ::= symbolScope->local(reference.Children[:ok(0)].Name, position))
		{
			WHILE(!symbolScope->is_root())
			{
				symbolScope := symbolScope->Parent;
				IF(item := symbolScope->local(reference.Children[:ok(0)].Name, position))
					BREAK;
			}

			IF(!item)
				THROW <NotResolved>(:root(symbolScope, reference, "no such entity"));
		}

		/// Resolve the remaining symbol children.
		FOR(child ::= ++reference.Children!.start().ok())
		{
			IF:!(item_as_scope ::= <<ast::[scoper::Config]ScopeBase #*>>(item))
				IF(<<ast::PotentialScope #*>>(item))
					= :partially_resolved(item, reference, child.i(), &&child_templates);
				ELSE THROW <NotResolved>(:child(symbolScope, *item, child!,
					"parent cannot have children"));


			IF:!(next_child ::= item_as_scope->scope_item(child!.Name))
				THROW <NotResolved>(:child(symbolScope, *item, child!, "no such child"));

			symbolScope := item_as_scope;
			item := next_child;
		}

		= :resolved(item, &&child_templates);
	}


	:resolved{
		tip: ast::[scoper::Config]ScopeItem #\,
		templates: ast::[Config]TemplateArg -std::Vec -std::Vec &&
	}:
		AncestorTemplates := &&templates,
		Item := tip;

	:partially_resolved{
		tip: ast::[scoper::Config]ScopeItem #\,
		symbol: ast::[scoper::Config]Symbol #&,
		resolved_children: UM,
		templates: ast::[Config]TemplateArg -std::Vec -std::Vec &&
	}:
		AncestorTemplates := &&templates,
		Item := tip,
		ItemTemplates := &&AncestorTemplates[resolved_children],
		Rest(symbol, resolved_children, AncestorTemplates!)
	{
		AncestorTemplates.resize(resolved_children-1);
	}
}


::rlc::resolver NotResolved -> rlc::Error
{
	Scope: ast::[scoper::Config]ScopeBase #\;
	Name: ast::[scoper::Config]String;
	ParentName: ast::[scoper::Config]String - std::Opt;
	TemplateArg: UM - std::Opt;
	Reason: CHAR #\;

	:root{
		scope: ast::[scoper::Config]ScopeBase #\,
		reference: ast::[scoper::Config]Symbol #&,
		reason: CHAR #\
	} -> (reference.Children[:ok(0)].Position):
		Scope := scope,
		Name := reference.Children[:ok(0)].Name,
		Reason(reason);

	:child{
		parentScope: ast::[scoper::Config]ScopeBase #\,
		parent: ast::[scoper::Config]ScopeItem #&,
		child: ast::[scoper::Config]Symbol::Child #&,
		reason: CHAR #\
	} -> (child.Position):
		Scope := parentScope,
		ParentName := :a(parent.Name),
		Name := child.Name,
		Reason := reason;

	# OVERRIDE message(
		o: std::io::OStream &) VOID
	{
		std::io::write(o, "Resolving ", Name!++, " in ");
		
		IF(Scope->is_root())
			std::io::write(o, "global scope");
		ELSE
		{
			delim # ::= Scope->print_name(o) ?? "::" : "";
			IF(ParentName)
				std::io::write(o, delim, ParentName!++);
		}
		
		std::io::write(o, " failed");
		IF(Reason)
			std::io::write(o, ": ", Reason);
		IF(TemplateArg)
			std::io::write(o, "(template #", :dec(TemplateArg!), ")");
		std::io::write(o, ".");
	}
}