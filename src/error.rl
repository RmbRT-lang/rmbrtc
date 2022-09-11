INCLUDE 'std/error'

INCLUDE "src/file.rl"

::rlc Error VIRTUAL -> std::Error
{
	Position: src::Position;

	{...};

	# FINAL stream(o: std::io::OStream &) VOID
	{
		std::io::write(o, :stream(Position), ": ");

		message(o);
	}

	# ABSTRACT message(o: std::io::OStream &) VOID;
}