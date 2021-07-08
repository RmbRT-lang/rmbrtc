INCLUDE "../expression.rl"
INCLUDE "../symbol.rl"

(// Rework expression structure:
	- Expressions for constants (number, BOOL, string, CHAR, this),
	- Expression for symbols,
	- Expression for '.', '->' (ptrs to obj and member desc),
	- Expression for operators.
	- Expression for cast. /)

::rlc::resolver::detail
	create_expression(
		scope: scoper::Scope #\,
		ref: scoper::Expression #\
	) Expression \
{
	SWITCH(type ::= ref->type())
	{
	DEFAULT:
		THROW std::err::Unimplemented(type.NAME());
	CASE :symbol:
		RETURN std::[ReferenceExpression]new(<scoper::SymbolExpression #\>(ref), scope);
	CASE :number:
		RETURN std::[NumberExpression]new(<scoper::NumberExpression #\>(ref));
	CASE :bool:
		RETURN std::[BoolExpression]new(<scoper::BoolExpression #\>(ref));
	CASE :char:
		RETURN std::[CharExpression]new(<scoper::CharExpression #\>(ref));
	CASE :string:
		RETURN std::[StringExpression]new(<scoper::StringExpression #\>(ref));
	CASE :operator:
		{
			op ::= <scoper::OperatorExpression #\>(ref);
			SWITCH(op->Op)
			{
			DEFAULT:
				RETURN std::[OperatorExpression]new(op, scope);
			CASE Operator::memberReference, Operator::memberPointer:
				RETURN std::[MemberAccessExpression]new(op, scope);
			}
		}
	CASE :this:
		RETURN std::[ThisExpression]new();
	CASE :null:
		RETURN std::[NullExpression]new();
	CASE :cast:
		RETURN std::[CastExpression]new(<scoper::CastExpression #\>(ref), scope);
	CASE :sizeof:
		RETURN std::[SizeofExpression]new(<scoper::SizeofExpression #\>(ref), scope);
	CASE :symbolConstant:
		RETURN std::[SymbolConstantExpression]new(<scoper::SymbolConstantExpression #\>(ref));
	}
}

::rlc::resolver
{
	ReferenceExpression -> Expression
	{
		Symbol: resolver::Symbol;

		# FINAL type() Expression::Type := :reference;

		{
			ref: scoper::SymbolExpression #\,
			scope: scoper::Scope #\
		}:	Symbol(:resolve(*scope, ref->Symbol, ref->Position));
	}

	ConstantExpression VIRTUAL -> Expression
	{
		ENUM Type
		{
			number,
			bool,
			char,
			string,
			this,
			null,
			sizeof,
			symbol
		}

		# FINAL type() Expression::Type := :constant;

		# ABSTRACT value_type() ConstantExpression::Type;
	}

	MemberAccessExpression -> Expression
	{
		# FINAL type() Expression::Type := :member;

		Lhs: Expression - std::Dynamic;
		MemberName: scoper::String;
		MemberTemplates: TemplateArg - std::Dynamic - std::Vector;
		IsPtr: BOOL;

		{
			ref: scoper::OperatorExpression #\,
			scope: scoper::Scope #\
		}:	Lhs(:gc(Expression::create(scope, ref->Operands[0]))),
			IsPtr(ref->Op == Operator::memberPointer)
		{
			child ::= &<scoper::SymbolChildExpression #\>(&*ref->Operands[1])->Child;
			MemberName := child->Name;
			FOR(tpl ::= child->Templates.start(); tpl; ++tpl)
				MemberTemplates += :gc(TemplateArg::create(scope, *tpl));
		}
	}

	OperatorExpression -> Expression
	{
		# FINAL type() Expression::Type := :operator;
		Op: Operator;
		Args: Expression - std::Dynamic - std::Vector;

		{
			ref: scoper::OperatorExpression #\,
			scope: scoper::Scope #\
		}:
			Op(ref->Op)
		{
			FOR(i ::= 0; i < ##ref->Operands; i++)
				Args += :gc(Expression::create(scope, ref->Operands[i]));
		}
	}

	CastExpression -> Expression
	{
		# FINAL type() Expression::Type := :cast;
		TYPE Kind := scoper::CastExpression::Kind;

		Method: Kind;
		Type: resolver::Type - std::Dynamic;
		Values: Expression - std::Dynamic - std::Vector;

		{
			ref: scoper::CastExpression #\,
			scope: scoper::Scope #\
		}:
			Type(:gc(resolver::Type::create(scope, ref->Type))),
			Method(ref->Method)
		{
			FOR(it ::= ref->Values.start(); it; ++it)
				Values += :gc(Expression::create(scope, *it));
		}
	}

	SizeofExpression -> ConstantExpression
	{
		Term: util::[resolver::Type; Expression]DynUnion;
		{
			ref: scoper::SizeofExpression #\,
			scope: scoper::Scope #\
		}
		{
			IF(ref->Term.is_first())
				Term := :gc(resolver::Type::create(scope, ref->Term.first()));
			ELSE
				Term := :gc(Expression::create(scope, ref->Term.second()));
		}

		# FINAL value_type() ConstantExpression::Type := :sizeof;
	}

	ThisExpression -> ConstantExpression
	{
		# FINAL value_type() ConstantExpression::Type := :this;
	}

	NullExpression -> ConstantExpression
	{
		# FINAL value_type() ConstantExpression::Type := :null;
	}

	BoolExpression -> ConstantExpression
	{
		# FINAL value_type() ConstantExpression::Type := :bool;
		Value: BOOL;

		{ref: scoper::BoolExpression #\}: Value(ref->Value);
	}

	NumberExpression -> ConstantExpression
	{
		# FINAL value_type() ConstantExpression::Type := :number;

		Number: scoper::Number;
		{ref: scoper::NumberExpression #\}: Number(ref->Number);
	}

	StringExpression -> ConstantExpression
	{
		# FINAL value_type() ConstantExpression::Type := :string;
		String: scoper::Text;
		{ref: scoper::StringExpression #\}: String(ref->String);
	}

	CharExpression -> ConstantExpression
	{
		# FINAL value_type() ConstantExpression::Type := :char;
		Char: scoper::Text;
		{ref: scoper::CharExpression #\}: Char(ref->Char);
	}

	SymbolConstantExpression -> ConstantExpression
	{
		# FINAL value_type() ConstantExpression::Type := :symbol;
		Name: scoper::String;
		{ref: scoper::SymbolConstantExpression #\}: Name(ref->Name);
	}
}