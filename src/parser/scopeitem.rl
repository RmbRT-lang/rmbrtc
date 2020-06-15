INCLUDE "templatedecl.rl"

::rlc::parser ScopeItem
{
	ENUM Category
	{
		global,
		member
	}

	Templates: TemplateDecl;

	# ABSTRACT category() ScopeItem::Category;

	# ABSTRACT name() src::String#&;
}