::rlc::parser ScopeItem
{
	ENUM Category
	{
		global,
		member
	}

	# ABSTRACT category() ScopeItem::Category;

	# ABSTRACT name() src::String#&;
}