INCLUDE "../expression.rl"

INCLUDE "../string.rl"
INCLUDE "../number.rl"
INCLUDE "../symbol.rl"

INCLUDE 'std/err/unimplemented'

::rlc::scoper::detail expression_create(
	position: UM,
	parsed: parser::Expression #\,
	file: src::File#&
) Expression \
{
	SWITCH(type ::= parsed->type())
	{
	DEFAULT:
		THROW <std::err::Unimplemented>(type.NAME());
	CASE :symbol:
		RETURN std::[SymbolExpression]new(position, <parser::SymbolExpression #\>(parsed), file);
	CASE :symbolChild:
		RETURN std::[SymbolChildExpression]new(<parser::SymbolChildExpression #\>(parsed), file);
	CASE :symbolConstant:
		RETURN std::[SymbolConstantExpression]new(<parser::SymbolConstantExpression #\>(parsed), file);
	CASE :number:
		RETURN std::[NumberExpression]new(<parser::NumberExpression #\>(parsed), file);
	CASE :bool:
		RETURN std::[BoolExpression]new(<parser::BoolExpression #\>(parsed));
	CASE :char:
		RETURN std::[CharExpression]new(<parser::CharExpression #\>(parsed), file);
	CASE :string:
		RETURN std::[StringExpression]new(<parser::StringExpression #\>(parsed), file);
	CASE :operator:
		RETURN std::[OperatorExpression]new(position, <parser::OperatorExpression #\>(parsed), file);
	CASE :this:
		RETURN std::[ThisExpression]new();
	CASE :null:
		RETURN std::[NullExpression]new();
	CASE :cast:
		RETURN std::[CastExpression]new(position, <parser::CastExpression #\>(parsed), file);
	CASE :sizeof:
		RETURN std::[SizeofExpression]new(position, <parser::SizeofExpression #\>(parsed), file);
	}
}

::rlc::scoper
{
	SymbolExpression -> Expression
	{
		# FINAL type() ExpressionType := :symbol;

		Symbol: scoper::Symbol;

		{
			position: UM,
			parsed: parser::SymbolExpression #\,
			file: src::File#&
		}->	Expression(position)
		:	Symbol(parsed->Symbol, file);
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

		Name: String;

		{
			parsed: parser::SymbolConstantExpression #\,
			file: src::File#&
		}:	Name(file.content(parsed->Symbol));
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

		Value: BOOL;

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
		}:	Char((:stringApostrophe, parsed->Char, parsed->Position), file);
	}

	StringExpression -> Expression
	{
		# FINAL type() ExpressionType := :string;
		String: Text;

		{
			parsed: parser::StringExpression #\,
			file: src::File#&
		}:	String(tok::Token(:stringQuote, parsed->String, parsed->Position), file);
	}

	OperatorExpression -> Expression
	{
		# FINAL type() ExpressionType := :operator;

		Operands: Expression - std::DynVector;
		Op: Operator;

		{
			position: UM,
			parsed: parser::OperatorExpression #\,
			file: src::File#&
		}->	Expression(position)
		:	Op(parsed->Op)
		{
			FOR(i ::= 0; i < ##parsed->Operands; i++)
				Operands += :gc(<<<Expression>>>(position, parsed->Operands[i], file));
		}
	}

	ThisExpression -> Expression
	{
		# FINAL type() ExpressionType := :this;
	}

	NullExpression -> Expression
	{
		# FINAL type() ExpressionType := :null;
	}

	CastExpression -> Expression
	{
		# FINAL type() ExpressionType := :cast;
		TYPE Kind := parser::CastExpression::Kind;

		Method: Kind;
		Type: std::[scoper::Type]Dynamic;
		Values: Expression-std::DynVector;

		{
			position: UM,
			parsed: parser::CastExpression #\,
			file: src::File#&
		}->	Expression(position)
		:	Type(:gc, <<<scoper::Type>>>(parsed->Type, file)),
			Method(parsed->Method)
		{
			FOR(i ::= 0; i < ##parsed->Values; i++)
				Values += :gc(<<<Expression>>>(position, parsed->Values[i], file));
		}
	}

	SizeofExpression -> Expression
	{
		# FINAL type() ExpressionType := :sizeof;

		Term: util::[Type; Expression]DynUnion;

		{
			position: UM,
			parsed: parser::SizeofExpression #\,
			file: src::File #&
		}->	Expression(position)
		{
			IF(parsed->Term.is_type())
				Term := :gc(<<<Type>>>(parsed->Term.type(), file));
			ELSE
				Term := :gc(<<<Expression>>>(position, parsed->Term.expression(), file));
		}
	}
}