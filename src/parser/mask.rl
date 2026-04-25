INCLUDE "members.rl"

// It would be good to be able to compose multiple things into a mask or something, for example when composing a pipeline of functions.
::rlc::parser Mask
{
	Name: Identifier;
	File: src::File;

	Members: parser::MemberScopeID;
	Ops: parser::Operators;
}
