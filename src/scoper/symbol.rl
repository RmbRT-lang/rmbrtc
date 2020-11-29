INCLUDE "../parser/symbol.rl"

INCLUDE "types.rl"
INCLUDE "typeorexpr.rl"

INCLUDE 'std/vector'

::rlc::scoper Symbol
{
	Child
	{
		Name: String;
		Templates: TypeOrExpr - std::Vector;

		CONSTRUCTOR(
			parsed: parser::Symbol::Child #&,
			file: src::File #&):
			Name(file.content(parsed.Name))
		{
			FOR(i ::= 0; i < parsed.Templates.size(); i++)
				IF(parsed.Templates[i].is_type())
					Templates.emplace_back(Type::create(parsed.Templates[i].type(), file));
				ELSE
					Templates.emplace_back(Expression::create(parsed.Templates[i].expression(), file));
		}
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