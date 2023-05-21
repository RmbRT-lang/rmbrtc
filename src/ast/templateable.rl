::rlc::ast [Stage: TYPE] Templateable VIRTUAL
{
	TemplateScope -> [Stage]ScopeBase, [Stage]TemplateDecl
	{
		:childOf{parent: [Stage]ScopeBase \} -> (:childOf, parent), ();

		:transform{
			p: [Stage::Prev+]Templateable::TemplateScope #&,
			ctx: Stage::Context+ #&
		} -> (:childOf, ctx.Parent), (:transform, p, ctx);

		# FINAL scope_item(Stage::Name #&) [Stage]ScopeItem #* := NULL;

		# FINAL local(name: Stage::Name #&, LocalPosition) [Stage]ScopeItem #*
		{
			FOR(arg ::= THIS.Arguments.start().ok())
				IF(arg!.Name == name)
					= &arg!;
			= NULL;
		}
	}

	Templates: TemplateScope;

	# has_templates() BOOL INLINE := Templates.exists();

	:childOf{parent: [Stage]ScopeBase \}: TemplateScope := :childOf(parent);

	:transform{
		p: [Stage::Prev+]Templateable #&,
		ctx: Stage::Context+ #&
	}:
		Templates := :transform(p.Templates, ctx);
}