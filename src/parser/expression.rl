INCLUDE "symbol.rl"
INCLUDE "parser.rl"
INCLUDE "type.rl"

::rlc::parser
{
	ENUM ExpressionType
	{
		symbol,
		symbolChild,
		number,
		char,
		string
	}

	Expression
	{
		# ABSTRACT type() ExpressionType;

		Range: src::String;

		STATIC parse(
			p: Parser &) Expression *
		{
			IF(p.consume(tok::Type::parentheseOpen))
			{
				exp ::= Expression::parse(p);
				p.expect(tok::Type::parentheseClose);
			}

			{
				v: SymbolExpression;
				IF(v.parse(p))
					RETURN ::[TYPE(v)]new(__cpp_std::move(v));
			}
			{
				v: SymbolChildExpression;
				IF(v.parse(p))
					RETURN ::[TYPE(v)]new(__cpp_std::move(v));
			}
			{
				v: NumberExpression;
				IF(v.parse(p))
					RETURN ::[TYPE(v)]new(__cpp_std::move(v));
			}
			{
				v: CharExpression;
				IF(v.parse(p))
					RETURN ::[TYPE(v)]new(__cpp_std::move(v));
			}
			{
				v: StringExpression;
				IF(v.parse(p))
					RETURN ::[TYPE(v)]new(__cpp_std::move(v));
			}

			RETURN NULL;
		}
	}

	SymbolExpression -> Expression
	{
		# FINAL type() ExpressionType := ExpressionType::symbol;

		Symbol: parser::Symbol;

		parse(p: Parser &) bool := Symbol.parse(p);
	}

	SymbolChildExpression -> Expression
	{
		# FINAL type() ExpressionType := ExpressionType::symbolChild;

		Child: Symbol::Child;

		parse(p: Parser &) bool := Child.parse(p);
	}

	NumberExpression -> Expression
	{
		# FINAL type() ExpressionType := ExpressionType::symbolChild;

		Number: src::String;

		parse(p: Parser &) bool := p.consume(tok::Type::numberLiteral, &Number);
	}

	CharExpression -> Expression
	{
		# FINAL type() ExpressionType := ExpressionType::char;

		Char: src::String;

		parse(p: Parser &) bool := p.consume(tok::Type::numberLiteral, &Char);
	}

	StringExpression -> Expression
	{
		# FINAL type() ExpressionType := ExpressionType::char;

		String: src::String;

		parse(p: Parser &) bool := p.consume(tok::Type::numberLiteral, &String);
	}
}