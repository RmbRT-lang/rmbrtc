INCLUDE "members.rl"

::rlc::parser Enum
{
	Name: Identifier;
	File: src::File;

	DefaultField: S2; // -1 if none
	TruthyFields: U8; // can only have up to 64 fields if truthy members exist.

	Members: parser::MemberScopeID;
}