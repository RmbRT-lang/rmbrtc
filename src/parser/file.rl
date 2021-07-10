INCLUDE "include.rl"
INCLUDE "detail/member.rl"
INCLUDE "detail/global.rl"

INCLUDE "../src/file.rl"

INCLUDE 'std/vector'
INCLUDE 'std/io/file'
INCLUDE 'std/io/stream'

::rlc::parser File
{
	Src: src::File;
	Includes: std::[Include]Vector;
	RootScope: Global - std::DynVector;
	Number: src::FileNo;

	# name() std::Utf8#& := Src.Name;

	{name: std::Utf8, fileNo: src::FileNo}: Src(name), Number(fileNo)
	{
		p: Parser(&Src, fileNo);
		inc: Include;
		WHILE(inc.parse(p))
			Includes += inc;

		WHILE(entry ::= Global::parse(p))
			RootScope += :gc(&&entry);

		IF(!p.eof())
			p.fail("expected scope entry");
	}
}