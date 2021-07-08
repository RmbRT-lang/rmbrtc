INCLUDE "../src/file.rl"
INCLUDE "fileregistry.rl"

INCLUDE 'std/error'
INCLUDE 'std/io/format'

::rlc::scoper Error VIRTUAL
{
	Position: src::Position;

	{
		position: src::Position
	}:	Position(position);


	# print(o: std::io::OStream &, files: FileRegistry #&) VOID
	{
		o.write_all(files.nameByNumber(Position.File), ':');
		std::io::format::dec(o, <UM>(Position.Line)+1);
		o.write(':');
		std::io::format::dec(o, <UM>(Position.Column)+1);
		o.write(": ");
		print_msg(o);
	}

	PROTECTED # ABSTRACT print_msg(o: std::io::OStream &) VOID;
}