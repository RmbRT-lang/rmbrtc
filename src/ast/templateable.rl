::rlc::ast [Stage: TYPE] Templateable VIRTUAL
{
	Templates: Stage-TemplateDecl;

	:transform{
		p: [Stage::Prev+]Templateable #&,
		f: Stage::PrevFile+,
		s: Stage &
	}:
		Templates := :transform(p.Templates, f, s);
}