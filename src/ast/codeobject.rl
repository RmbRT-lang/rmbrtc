(//
A code object is something that has a definite location in the code, where the location may be important for error reporting and other diagnostics.
/)
::rlc::ast CodeObject
{
	(// The position in the code where the scope item is defined. /)
	Position: src::Position;

	{...};
}