INCLUDE "members.rl"

::rlc::parser Rawtype
{
	Name: Identifier;
	File: src::File;
	Templates: parser::TokenSpan;

	Size:      TokenSpan;
	Alignment: TokenSpan;

	Ctors:   parser::Constructors;
	Members: parser::Members;
	Ops:     parser::Operators;

	{BARE};
}