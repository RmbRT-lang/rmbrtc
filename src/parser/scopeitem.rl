INCLUDE "templatedecl.rl"

::rlc::parser ScopeItem VIRTUAL
{
	ENUM Type
	{
		namespace,
		typedef,
		function,
		variable,
		class,
		mask,
		rawtype,
		union,
		enum,
		enumConstant,
		externSymbol,
		test,

		destructor,
		constructor
	}

	Templates: TemplateDecl;

	# ABSTRACT type() Type;
	# ABSTRACT overloadable() BOOL;
	# ABSTRACT name() src::String#&;
}