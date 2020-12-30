INCLUDE "../expression.rl"

INCLUDE "../string.rl"
INCLUDE "../number.rl"
INCLUDE "../symbol.rl"

INCLUDE 'std/err/unimplemented'

::rlc::scoper::detail expression_create(
	parsed: parser::Expression #\,
	file: src::File#&
) Expression \
{
	SWITCH(type ::= parsed->type())
	{
	DEFAULT:
		THROW std::err::Unimplemented(type.NAME());
	CASE :symbol:
		RETURN ::[SymbolExpression]new(<parser::SymbolExpression #\>(parsed), file);
	CASE :symbolChild:
		RETURN ::[SymbolChildExpression]new(<parser::SymbolChildExpression #\>(parsed), file);
	CASE :symbolConstant:
		RETURN ::[SymbolConstantExpression]new(<parser::SymbolConstantExpression #\>(parsed), file);
	CASE :number:
		RETURN ::[NumberExpression]new(<parser::NumberExpression #\>(parsed), file);
	CASE :bool:
		RETURN ::[BoolExpression]new(<parser::BoolExpression #\>(parsed));
	CASE :char:
		RETURN ::[CharExpression]new(<parser::CharExpression #\>(parsed), file);
	CASE :string:
		RETURN ::[StringExpression]new(<parser::StringExpression #\>(parsed), file);
	CASE :operator:
		RETURN ::[OperatorExpression]new(<parser::OperatorExpression #\>(parsed), file);
	CASE :this:
		RETURN ::[ThisExpression]new();
	CASE :cast:
		RETURN ::[CastExpression]new(<parser::CastExpression #\>(parsed), file);
	CASE :sizeof:
		RETURN ::[SizeofExpression]new(<parser::SizeofExpression #\>(parsed), file);
	}
}

::rlc::scoper
{
	SymbolExpression -> Expression
	{
		# FINAL type() ExpressionType := :symbol;

		Symbol: scoper::Symbol;

		{
			parsed: parser::SymbolExpression #\,
			file: src::File#&
		}:	Symbol(parsed->Symbol, file);
	}

	SymbolChildExpression -> Expression
	{
		# FINAL type() ExpressionType := :symbolChild;

		Child: Symbol::Child;

		{
			parsed: parser::SymbolChildExpression #\,
			file: src::File#&
		}:	Child(parsed->Child, file);
	}

	SymbolConstantExpression -> Expression
	{
		# FINAL type() ExpressionType := :symbolConstant;

		Child: String;

		{
			parsed: parser::SymbolConstantExpression #\,
			file: src::File#&
		}:	Child(file.content(parsed->Symbol));
	}

	NumberExpression -> Expression
	{
		# FINAL type() ExpressionType := :number;

		Number: scoper::Number;

		{
			parsed: parser::NumberExpression #\,
			file: src::File#&
		}:	Number(parsed->Number, file);
	}

	BoolExpression -> Expression
	{
		# FINAL type() ExpressionType := :bool;

		Value: bool;

		{
			parsed: parser::BoolExpression #\
		}:	Value(parsed->Value);
	}

	CharExpression -> Expression
	{
		# FINAL type() ExpressionType := :char;
		Char: Text;

		{
			parsed: parser::CharExpression #\,
			file: src::File#&
		}:	Char(tok::Token(:stringApostrophe, parsed->Char), file);
	}

	StringExpression -> Expression
	{
		# FINAL type() ExpressionType := :string;
		String: Text;

		{
			parsed: parser::StringExpression #\,
			file: src::File#&
		}:	String(tok::Token(:stringQuote, parsed->String), file);
	}

	OperatorExpression -> Expression
	{
		# FINAL type() ExpressionType := :operator;

		Operands: std::[std::[Expression]Dynamic]Vector;
		Op: Operator;

		{
			parsed: parser::OperatorExpression #\,
			file: src::File#&
		}:	Op(parsed->Op)
		{
			FOR(i ::= 0; i < parsed->Operands.size(); i++)
				Operands += :gc(Expression::create(parsed->Operands[i], file));
		}
	}

	ThisExpression -> Expression
	{
		# FINAL type() ExpressionType := :this;
	}

	CastExpression -> Expression
	{
		# FINAL type() ExpressionType := :cast;

		Type: std::[scoper::Type]Dynamic;
		Values: Expression-std::Dynamic-std::Vector;

		{
			parsed: parser::CastExpression #\,
			file: src::File#&
		}:	Type(:gc, Type::create(parsed->Type, file))
		{
			FOR(i ::= 0; i < parsed->Values.size(); i++)
				Values += :gc(Expression::create(parsed->Values[i], file));
		}
	}

	SizeofExpression -> Expression
	{
		# FINAL type() ExpressionType := :sizeof;

		Term: util::[Type, Expression]DynUnion;

		{
			parsed: parser::SizeofExpression #\,
			file: src::File #&}
		{
			IF(parsed->Term.is_type())
				Term := Type::create(parsed->Term.type(), file);
			ELSE
				Term := Expression::create(parsed->Term.expression(), file);
		}
	}
}