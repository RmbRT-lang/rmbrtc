::rlc::ast [Stage: TYPE] Templateable VIRTUAL -> [Stage]ScopeBase
{
	Templates: Stage-TemplateDecl;

	:childOf{parent: [Stage]ScopeBase \} -> (:childOf, parent);

	:transform{
		p: [Stage::Prev+]Templateable #&,
		f: Stage::PrevFile+,
		s: Stage &,
		parent: [Stage]ScopeBase \
	} -> (:childOf, parent):
		Templates := :transform(p.Templates, f, s, parent);
}