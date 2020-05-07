INCLUDE "include.rl"
INCLUDE "scopeentry.rl"

INCLUDE "../src/file.rl"

INCLUDE 'std/vector'
INCLUDE 'std/io/file'
INCLUDE 'std/io/stream'

::rlc::parser File
{
	Src: src::File;
	Includes: std::[Include]Vector;
	RootScope: std::[std::[ScopeEntry]Dynamic]Vector;
	
	# name() std::Utf8#& := Src.Name;

	CONSTRUCTOR(name: std::Utf8): Src(name)
	{
		out ::= std::io::OStream::from(&std::io::out);
		p: Parser(&Src);
		inc: Include;
		WHILE(inc.parse(p))
		{
			printf("include ");
			out.write(Src.content(inc.Token.Content));
			printf("\n");
			Includes.push_back(inc);
		}

		WHILE(entry ::= ScopeEntry::parse(p))
		{
			printf("::");
			out.write(Src.content(entry->Name));
			printf("\n");

			RootScope.push_back(__cpp_std::move(entry));
		}
	}
}