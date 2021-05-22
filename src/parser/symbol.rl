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

			parse(p: Parser&) BOOL := parse(p, FALSE);
			parse(
				p: Parser &,
				isValue: BOOL) BOOL
			{
				IF(p.consume(:bracketOpen))
				{
					IF(!p.consume(:bracketClose))
					{
						DO()
						{
							tArg: TemplateArg;
							IF(p.consume(:hash))
							{
								IF(!(tArg := Expression::parse(p)))
									p.fail("expected expression");
							} ELSE
							{
								IF(!(tArg := Type::parse(p)))
									p.fail("expected type");
							}
							Templates += &&tArg;
						} WHILE(p.consume(:comma))
						p.expect(:bracketClose);
					}
					IF(!isValue
					|| !p.consume(:destructor, &Name))
						p.expect(:identifier, &Name);
					RETURN TRUE;
				} ELSE
				{
					RETURN p.consume(:identifier, &Name)
						|| (isValue
							&& p.consume(:destructor, &Name));
						
				}
			}
		}

		Children: std::[Child]Vector;
		IsRoot: BOOL;

		parse(p: Parser&) BOOL := parse(p, FALSE);
		parse(
			p: Parser &,
			isValue: BOOL) BOOL
		{
			t: Trace(&p, "symbol");

			IsRoot := p.consume(:doubleColon);
			expect ::= IsRoot;

			DO(child: Child)
			{
				IF(!child.parse(p, isValue))
				{
					IF(expect)
						p.fail("expected symbol child");
					RETURN FALSE;
				}

				Children += &&child;
			} FOR(p.consume(:doubleColon); expect := TRUE)

			RETURN TRUE;
		}
	}

	SymbolChildExpression -> Expression
	{
		# FINAL type() ExpressionType := :symbolChild;

		Child: Symbol::Child;

		parse(p: Parser &) BOOL := Child.parse(p, TRUE);
	}

	SymbolExpression -> Expression
	{
		# FINAL type() ExpressionType := :symbol;

		Symbol: parser::Symbol;

		parse(p: Parser &) BOOL := Symbol.parse(p, TRUE);
	}
}