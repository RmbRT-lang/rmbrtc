INCLUDE "../parser/symbol.rl"

INCLUDE "types.rl"
INCLUDE "typeorexpr.rl"

INCLUDE 'std/vector'

::rlc::scoper Symbol
{
	Child
	{
		Name: String;
		Templates: TypeOrExpr - std::Vector - std::Vector;

		{
			parsed: parser::Symbol::Child #&,
			file: src::File #&}:
			Name(file.content(parsed.Name))
		{
			FOR(i ::= 0; i < parsed.Templates.size(); i++)
			{
				arg: TypeOrExpr - std::Vector;
				FOR(it ::= parsed.Templates[i].start(); it; ++it)
					IF(it->is_type())
						arg += Type::create(it->type(), file);
					ELSE
						arg += Expression::create(it->expression(), file);
				Templates += &&arg;
			}
		}
	}

	Children: std::[Child]Vector;
	IsRoot: BOOL;

	{
		parsed: parser::Symbol #&,
		file: src::File #&}:
		IsRoot(parsed.IsRoot)
	{
		FOR(i ::= 0; i < parsed.Children.size(); i++)
			Children += (parsed.Children[i], file);
	}
}