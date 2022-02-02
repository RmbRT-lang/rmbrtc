::rlc::instantiator::detail create_member(
	res: resolver::Member #\,
	scope: Scope #&
) Member \
{
	TYPE SWITCH(res)
	{
	DEFAULT:
		THROW <std::err::Unimplemented>(TYPE(member));
	resolver::MemberTypedef:
		RETURN std::[MemberTypedef]new(<<resolver::MemberTypedef #\>>(member), scope);
	resolver::MemberFunction:
		RETURN std::[MemberFunction]new(<<resolver::MemberFunction#\>>(member), scope);
	resolver::MemberVariable:
		RETURN std::[MemberVariable]new(<<resolver::MemberVariable#\>>(member), scope);
	resolver::MemberClass:
		RETURN std::[MemberClass]new(<<resolver::MemberClass#\>>(member), scope);
	resolver::MemberRawtype:
		RETURN std::[MemberRawtype]new(<<resolver::MemberRawtype#\>>(member), scope);
	resolver::MemberUnion:
		RETURN std::[MemberUnion]new(<<resolver::MemberUnion#\>>(member), scope);
	resolver::MemberEnum:
		RETURN std::[MemberEnum]new(<<resolver::MemberEnum#\>>(member), scope);
	resolver::Constructor:
		RETURN std::[Constructor]new(<<resolver::Constructor#\>>(member), scope);
	resolver::Destructor:
		RETURN std::[Destructor]new(<<resolver::Destructor#\>>(member), scope);
	}
}

