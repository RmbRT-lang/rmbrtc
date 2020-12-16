INCLUDE 'std/math/safe'
INCLUDE 'std/types'
INCLUDE 'std/io/streamable'
INCLUDE 'std/io/format'
INCLUDE 'std/io/scan'

INCLUDE "types.rl"

::rlc::scoper Number
{
	TYPE Num := std::S8;
	Value: Num;

	{v: Num}: Value(v);
	{
		str: src::String #&,
		file: src::File #&
	}:	Number(file.content(str));

	{str: String #&}
	{
		IF(str.Size >= 2 && (str[1] == 'x' || str[1] == 'X'))
			std::io::scan::hex(str, Value);
		ELSE
			std::io::scan::dec(str, Value);
	}

	# value() INLINE ::= Value;

	# stream(o: std::io::OStream &) INLINE VOID
	{
		std::io::format::dec(o, Value);
	}
}