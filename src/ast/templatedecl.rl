INCLUDE "type.rl"


::rlc::ast
{
	ENUM TemplateDeclArgType { type, number, value }

	[Stage:TYPE] TemplateDecl
	{
		Arguments: Stage-TemplateArgDecl-std::DynVec;
	
		# exists() INLINE BOOL := ##Arguments != 0;
	}

	[Stage:TYPE] TemplateArgDecl VIRTUAL {
		Name: Stage::Name;
		Variadic: BOOL;

		# ABSTRACT type() TemplateDeclArgType;
	}

	[Stage:TYPE] TypeTemplateArgDecl -> [Stage]TemplateArgDecl
	{
		# FINAL type() TemplateDeclArgType := :type;
	}

	[Stage:TYPE] ValueTemplateArgDecl -> [Stage]TemplateArgDecl
	{
		Type: Stage-ast::Type - std::Dyn;
		# FINAL type() TemplateDeclArgType := :value;
	}

	[Stage:TYPE] NumberTemplateArgDecl -> [Stage]TemplateArgDecl
	{
		# FINAL type() TemplateDeclArgType := :number;
	}
}