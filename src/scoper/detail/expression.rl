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
	TYPE SWITCH(parsed)
	{
	DEFAULT:
		THROW <std::err::Unimplemented>(TYPE(parsed));
	CASE parser::SymbolExpression:
		RETURN std::[SymbolExpression]new(position, <parser::SymbolExpression #\>(parsed), file);
	CASE parser::SymbolChildExpression:
		RETURN std::[SymbolChildExpression]new(<parser::SymbolChildExpression #\>(parsed), file);
	CASE parser::SymbolConstantExpression:
		RETURN std::[SymbolConstantExpression]new(<parser::SymbolConstantExpression #\>(parsed), file);
	CASE parser::NumberExpression:
		RETURN std::[NumberExpression]new(<parser::NumberExpression #\>(parsed), file);
	CASE parser::BoolExpression:
		RETURN std::[BoolExpression]new(<parser::BoolExpression #\>(parsed));
	CASE parser::CharExpression:
		RETURN std::[CharExpression]new(<parser::CharExpression #\>(parsed), file);
	CASE parser::StringExpression:
		RETURN std::[StringExpression]new(<parser::StringExpression #\>(parsed), file);
	CASE parser::OperatorExpression:
		RETURN std::[OperatorExpression]new(position, <parser::OperatorExpression #\>(parsed), file);
	CASE parser::ThisExpression:
		RETURN std::[ThisExpression]new();
	CASE parser::NullExpression:
		RETURN std::[NullExpression]new();
	CASE parser::CastExpression:
		RETURN std::[CastExpression]new(position, <parser::CastExpression #\>(parsed), file);
	CASE parser::SizeofExpression:
		RETURN std::[SizeofExpression]new(position, <parser::SizeofExpression #\>(parsed), file);
	}
}

::rlc::scoper
{
	SymbolExpression -> Expression
	{
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
		Child: Symbol::Child;

		{
			parsed: parser::SymbolChildExpression #\,
			file: src::File#&
		}:	Child(parsed->Child, file);
	}

	SymbolConstantExpression -> Expression
	{
		Name: String;

		{
			parsed: parser::SymbolConstantExpression #\,
			file: src::File#&
		}:	Name(file.content(parsed->Symbol));
	}

	NumberExpression -> Expression
	{
		Number: scoper::Number;

		{
			parsed: parser::NumberExpression #\,
			file: src::File#&
		}:	Number(parsed->Number, file);
	}

	BoolExpression -> Expression
	{
		Value: BOOL;

		{
			parsed: parser::BoolExpression #\
		}:	Value(parsed->Value);
	}

	CharExpression -> Expression
	{
		Char: Text;

		{
			parsed: parser::CharExpression #\,
			file: src::File#&
		}:	Char((:stringApostrophe, parsed->Char, parsed->Position), file);
	}

	StringExpression -> Expression
	{
		String: Text;

		{
			parsed: parser::StringExpression #\,
			file: src::File#&
		}:	String(tok::Token(:stringQuote, parsed->String, parsed->Position), file);
	}

	OperatorExpression -> Expression
	{
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

	ThisExpression -> Expression { }

	NullExpression -> Expression { }

	CastExpression -> Expression
	{
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