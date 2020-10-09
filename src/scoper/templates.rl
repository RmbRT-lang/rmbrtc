INCLUDE "../parser/templatedecl.rl"

INCLUDE "types.rl"

::rlc::scoper
{
	TYPE TemplateDeclType := parser::TemplateDeclType;

	(// A single template argument declaration. /)
	TemplateDecl
	{
		Name: String;
		Type: TemplateDeclType;

		CONSTRUCTOR(name: String#&, type: TemplateDeclType):
			Name(name), Type(type);
	}

	(// A set of template argument declarations. /)
	TemplateDecls
	{
		Templates: std::[TemplateDecl]Vector;

		CONSTRUCTOR(
			parsed: parser::TemplateDecl #&,
			file: src::File #&)
		{
			FOR(i ::= 0; i < parsed.Children.size(); i++)
				Templates.emplace_back(
					file.content(parsed.Children[i].Name),
					parsed.Children[i].Type);
		}

		# find(name: String #&) TemplateDecl #*
		{
			FOR(i ::= 0; i < Templates.size(); i++)
				IF(std::str::cmp(Templates[i].Name, name) == 0)
					RETURN &Templates[i];
			RETURN NULL;
		}
	}
}