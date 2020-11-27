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
	CASE ExpressionType::symbol:
		RETURN ::[SymbolExpression]new(<parser::SymbolExpression #\>(parsed), file);
	CASE ExpressionType::symbolChild:
		RETURN ::[SymbolChildExpression]new(<parser::SymbolChildExpression #\>(parsed), file);
	CASE ExpressionType::number:
		RETURN ::[NumberExpression]new(<parser::NumberExpression #\>(parsed), file);
	CASE ExpressionType::bool:
		RETURN ::[BoolExpression]new(<parser::BoolExpression #\>(parsed));
	CASE ExpressionType::char:
		RETURN ::[CharExpression]new(<parser::CharExpression #\>(parsed), file);
	CASE ExpressionType::string:
		RETURN ::[StringExpression]new(<parser::StringExpression #\>(parsed), file);
	CASE ExpressionType::operator:
		RETURN ::[OperatorExpression]new(<parser::OperatorExpression #\>(parsed), file);
	CASE ExpressionType::this:
		RETURN ::[ThisExpression]new();
	CASE ExpressionType::cast:
		RETURN ::[CastExpression]new(<parser::CastExpression #\>(parsed), file);
	CASE ExpressionType::sizeof:
		RETURN ::[SizeofExpression]new(<parser::SizeofExpression #\>(parsed), file);
	}
}

::rlc::scoper
{
	SymbolExpression -> Expression
	{
		# FINAL type() ExpressionType := ExpressionType::symbol;

		Symbol: scoper::Symbol;

		CONSTRUCTOR(
			parsed: parser::SymbolExpression #\,
			file: src::File#&
		):	Symbol(parsed->Symbol, file);
	}

	SymbolChildExpression -> Expression
	{
		# FINAL type() ExpressionType := ExpressionType::symbolChild;

		Child: Symbol::Child;

		CONSTRUCTOR(
			parsed: parser::SymbolChildExpression #\,
			file: src::File#&
		):	Child(parsed->Child, file);
	}

	NumberExpression -> Expression
	{
		# FINAL type() ExpressionType := ExpressionType::number;

		Number: scoper::Number;

		CONSTRUCTOR(
			parsed: parser::NumberExpression #\,
			file: src::File#&
		):	Number(parsed->Number, file);
	}

	BoolExpression -> Expression
	{
		# FINAL type() ExpressionType := ExpressionType::bool;

		Value: bool;

		CONSTRUCTOR(
			parsed: parser::BoolExpression #\
		):	Value(parsed->Value);
	}

	CharExpression -> Expression
	{
		# FINAL type() ExpressionType := ExpressionType::char;
		Char: Text;

		CONSTRUCTOR(
			parsed: parser::CharExpression #\,
			file: src::File#&
		):	Char(tok::Token(tok::Type::stringApostrophe, parsed->Char), file);
	}

	StringExpression -> Expression
	{
		# FINAL type() ExpressionType := ExpressionType::string;
		String: Text;

		CONSTRUCTOR(
			parsed: parser::StringExpression #\,
			file: src::File#&
		):	String(tok::Token(tok::Type::stringQuote, parsed->String), file);
	}

	OperatorExpression -> Expression
	{
		# FINAL type() ExpressionType := ExpressionType::operator;

		Operands: std::[std::[Expression]Dynamic]Vector;
		Op: Operator;

		CONSTRUCTOR(
			parsed: parser::OperatorExpression #\,
			file: src::File#&
		):	Op(parsed->Op)
		{
			FOR(i ::= 0; i < parsed->Operands.size(); i++)
				Operands.push_back(Expression::create(parsed->Operands[i], file));
		}
	}

	ThisExpression -> Expression
	{
		# FINAL type() ExpressionType := ExpressionType::this;
	}

	CastExpression -> Expression
	{
		# FINAL type() ExpressionType := ExpressionType::cast;

		Type: std::[scoper::Type]Dynamic;
		Value: std::[Expression]Dynamic;

		CONSTRUCTOR(
			parsed: parser::CastExpression #\,
			file: src::File#&
		):	Type(Type::create(parsed->Type, file)),
			Value(Expression::create(parsed->Value, file));
	}

	SizeofExpression -> Expression
	{
		# FINAL type() ExpressionType := ExpressionType::sizeof;

		Term: util::[Type, Expression]DynUnion;

		CONSTRUCTOR(
			parsed: parser::SizeofExpression #\,
			file: src::File #&)
		{
			IF(parsed->Term.is_type())
				Term := Type::create(parsed->Term.type(), file);
			ELSE
				Term := Expression::create(parsed->Term.expression(), file);
		}
	}
}