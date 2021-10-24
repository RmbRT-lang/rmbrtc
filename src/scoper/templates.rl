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
		Variadic: BOOL;

		{name: String#&, type: TemplateDeclType, variadic: BOOL}:
			Name(name), Type(type), Variadic(variadic);
	}

	(// A set of template argument declarations. /)
	TemplateDecls
	{
		Templates: std::[TemplateDecl]Vector;

		{
			parsed: parser::TemplateDecl #&,
			file: src::File #&}
		{
			FOR(i ::= 0; i < ##parsed.Children; i++)
				Templates += (
					file.content(parsed.Children[i].Name),
					parsed.Children[i].Type,
					parsed.Children[i].Variadic);
		}

		# find(name: String #&) TemplateDecl #*
		{
			FOR(i ::= 0; i < ##Templates; i++)
				IF(std::str::cmp(Templates[i].Name, name) == 0)
					RETURN &Templates[i];
			RETURN NULL;
		}

		# THIS! INLINE #& ::= Templates;
		# ##THIS INLINE UM := ##Templates;
		# <BOOL> INLINE := ##Templates != 0;
	}
}