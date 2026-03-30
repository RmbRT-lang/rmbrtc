INCLUDE "members.rl"

::rlc::parser Union
{
	Name: Identifier;
	File: src::File;
	Templates: parser::TokenSpan; // or already parsed?

	ValueOfField: S2; // -1 if none
	DefaultField: S2; // -1 if none
	TruthyFields: U8; // can only have up to 64 fields if truthy members exist.

	Members: parser::Members;
}