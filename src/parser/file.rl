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
	RootScope: std::[std::[Global]Dynamic]Vector;
	
	# name() std::Utf8#& := Src.Name;

	CONSTRUCTOR(name: std::Utf8): Src(name)
	{
		out ::= std::io::OStream::FROM(&std::io::out);
		p: Parser(&Src);
		inc: Include;
		WHILE(inc.parse(p))
			Includes.push_back(inc);

		WHILE(entry ::= Global::parse(p))
			RootScope.push_back(__cpp_std::move(entry));

		out.write(THIS->name().content());
		out.write('\n');
	}
}