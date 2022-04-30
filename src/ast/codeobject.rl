(//
A code object is something that has a definite location in the code, where the location may be important for error reporting and other diagnostics.
/)
::rlc::ast CodeObject
{
	(// The position in the code where the scope item is defined. /)
	Position: src::Position;

	/// Emits an error located for the code object.
	# error() VOID;

	/// Emits a warning located for the code object.
	# warning() VOID;

	/// Emits a log message for the code object.
	# log() VOID;
}