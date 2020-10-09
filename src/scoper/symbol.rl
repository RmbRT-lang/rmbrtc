INCLUDE "../parser/symbol.rl"

INCLUDE "types.rl"

INCLUDE 'std/vector'

::rlc::scoper Symbol
{
	Child
	{
		Name: String;

		CONSTRUCTOR(
			parsed: parser::Symbol::Child #&,
			file: src::File #&):
			Name(file.content(parsed.Name));
	}

	Children: std::[Child]Vector;
	IsRoot: bool;

	CONSTRUCTOR(
		parsed: parser::Symbol #&,
		file: src::File #&):
		IsRoot(parsed.IsRoot)
	{
		FOR(i ::= 0; i < parsed.Children.size(); i++)
			Children.emplace_back(parsed.Children[i], file);
	}
}