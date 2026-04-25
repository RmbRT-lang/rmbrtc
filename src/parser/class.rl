INCLUDE "members.rl"

::rlc::parser Class
{
	ENUM DeclMode {
	*	normal,
		abstract,
		final,
		virtual
	}

	Name: rlc::Identifier;
	File: src::File;
	Templates: TokenSpan;

	Decl: DeclMode;

	Inheritance: TokenSpan;
	Ctors: parser::Constructors;
	Members: parser::MemberScopeID;
	Ops: parser::Operators;


	{BARE};
}
