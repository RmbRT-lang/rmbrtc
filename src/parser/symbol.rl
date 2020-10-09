INCLUDE "parser.rl"
INCLUDE "type.rl"
INCLUDE "expression.rl"

INCLUDE "../src/file.rl"

INCLUDE 'std/vector'

::rlc::parser
{
	TYPE TemplateArg := TypeOrExpr;

	// std::[T]Vector
	Symbol
	{
		// [T]Vector
		Child
		{
			CONSTRUCTOR();
			CONSTRUCTOR(m: Symbol::Child &&):
				Name(m.Name),
				Templates(__cpp_std::move(m.Templates));

			Name: src::String;
			Templates: std::[TemplateArg]Vector;

			parse(p: Parser&) bool := parse(p, FALSE);
			parse(
				p: Parser &,
				isValue: bool) bool
			{
				IF(p.consume(tok::Type::bracketOpen))
				{
					IF(!p.consume(tok::Type::bracketClose))
					{
						DO()
						{
							tArg: TemplateArg;
							IF(p.consume(tok::Type::hash))
							{
								IF(!(tArg := Expression::parse(p)))
									p.fail("expected expression");
							} ELSE
							{
								IF(!(tArg := Type::parse(p)))
									p.fail("expected type");
							}
							Templates.push_back(__cpp_std::move(tArg));
						} WHILE(p.consume(tok::Type::comma))
						p.expect(tok::Type::bracketClose);
					}
					IF(!isValue
					|| (!p.consume(tok::Type::constructor, &Name)
						&& !p.consume(tok::Type::destructor, &Name)))
						p.expect(tok::Type::identifier, &Name);
					RETURN TRUE;
				} ELSE
				{
					RETURN p.consume(tok::Type::identifier, &Name)
						|| (isValue
							&& (p.consume(tok::Type::constructor, &Name)
								|| p.consume(tok::Type::destructor, &Name)));
						
				}
			}
		}

		Children: std::[Child]Vector;
		IsRoot: bool;

		parse(p: Parser&) bool := parse(p, FALSE);
		parse(
			p: Parser &,
			isValue: bool) bool
		{
			t: Trace(&p, "symbol");

			IsRoot := p.consume(tok::Type::doubleColon);
			expect ::= IsRoot;

			DO(child: Child)
			{
				IF(!child.parse(p, isValue))
				{
					IF(expect)
						p.fail("expected symbol child");
					RETURN FALSE;
				}

				Children.push_back(__cpp_std::move(child));
			} FOR(p.consume(tok::Type::doubleColon); expect := TRUE)

			RETURN TRUE;
		}
	}

	SymbolChildExpression -> Expression
	{
		# FINAL type() ExpressionType := ExpressionType::symbolChild;

		Child: Symbol::Child;

		parse(p: Parser &) bool := Child.parse(p, TRUE);
	}

	SymbolExpression -> Expression
	{
		# FINAL type() ExpressionType := ExpressionType::symbol;

		Symbol: parser::Symbol;

		parse(p: Parser &) bool := Symbol.parse(p, TRUE);
	}
}