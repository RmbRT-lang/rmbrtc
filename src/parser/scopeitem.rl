INCLUDE "templatedecl.rl"

::rlc::parser ScopeItem
{
	ENUM Category
	{
		global,
		member,
		local
	}

	Templates: TemplateDecl;

	# ABSTRACT category() ScopeItem::Category;

	# ABSTRACT name() src::String#&;
}