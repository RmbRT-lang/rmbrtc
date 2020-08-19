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
			Name: src::String;
			Templates: std::[TemplateArg]Vector;

			parse(
				p: Parser &) bool
			{
				IF(p.consume(tok::Type::bracketOpen)
				&& !p.consume(tok::Type::bracketClose))
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
					p.expect(tok::Type::identifier, &Name);
					RETURN TRUE;
				} ELSE
				{
					RETURN p.consume(tok::Type::identifier, &Name);
				}
			}
		}

		Children: std::[Child]Vector;
		IsRoot: bool;

		parse(
			p: Parser &) bool
		{
			t: Trace(&p, "symbol");

			IsRoot := p.consume(tok::Type::doubleColon);
			expect ::= IsRoot;

			DO(child: Child)
			{
				IF(!child.parse(p))
				{
					IF(expect)
						p.fail("expected symbol child");
					RETURN FALSE;
				}

				Children.push_back(__cpp_std::move(child));
			} WHILE(p.consume(tok::Type::doubleColon))

			RETURN TRUE;
		}
	}

	SymbolChildExpression -> Expression
	{
		# FINAL type() ExpressionType := ExpressionType::symbolChild;

		Child: Symbol::Child;

		parse(p: Parser &) bool := Child.parse(p);
	}

	SymbolExpression -> Expression
	{
		# FINAL type() ExpressionType := ExpressionType::symbol;

		Symbol: parser::Symbol;

		parse(p: Parser &) bool := Symbol.parse(p);
	}
}