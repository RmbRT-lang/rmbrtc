INCLUDE "members.rl"

::rlc::parser Rawtype
{
	Name: Identifier;
	File: src::File;
	Templates: parser::TokenSpan;

	Size:      ExpressionID;
	Alignment: ExpressionID;

	Ctors:   parser::Constructors;
	Members: parser::Members;
	Ops:     parser::Operators;

	{BARE};
}