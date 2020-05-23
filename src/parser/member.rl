::rlc ENUM Visibility
{
	public,
	protected,
	private
}

::rlc::parser Member -> ScopeItem
{
	# FINAL category() ScopeItem::Category := ScopeItem::Category::member;
	Visibility: rlc::Visibility;

	ENUM Type
	{
		typedef,
		function,
		variable
	}

	# ABSTRACT type() Member::Type;

	parse(p: Parser&) Member*
	{
		RETURN NULL;
	}
}