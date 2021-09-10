INCLUDE "templatedecl.rl"

::rlc::parser ScopeItem VIRTUAL
{
	Templates: TemplateDecl;

	# ABSTRACT overloadable() BOOL;
	# ABSTRACT name() src::String#&;
}