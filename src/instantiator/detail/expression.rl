INCLUDE "../expression.rl"
INCLUDE 'std/memory'

::rlc::instantiator::detail create_expression(
	expr: resolver::Expression #\,
	scope: Scope #&
) Expression \
{
	THROW;
	(/
	TYPE SWITCH(expr)
	{
	DEFAULT:
		THROW <std::err::Unimplemented>(TYPE(expr));
	resolver::ReferenceExpression:
		RETURN std::[ReferenceExpression]new(<<resolver::ReferenceExpression #\>>(expr), scope);
	resolver::ConstantExpression:
		RETURN <<<ConstantExpression>>>(<<resolver::ConstantExpression #\>>(expr), scope);
	resolver::MemberAccessExpression:
		RETURN std::[MemberAccessExpression]new(<<resolver::MemberAccessExpression #\>>(expr), scope);
	resolver::OperatorExpression:
		RETURN std::[OperatorExpression]new(<<resolver::OperatorExpression #\>>(expr), scope);
	resolver::CastExpression:
		RETURN std::[OperatorExpression]new(<<resolver::CastExpression #\>>(expr), scope);
	resolver::TypeofExpression:
		RETURN std::[TypeofExpression]new(<<resolver::TypeofExpression #\>>(expr), scope);
	}/)
}

::rlc::instantiator
{
	ReferenceExpression -> Expression
	{
		Reference: Instance \;

		{expr: resolver::ReferenceExpression #\, scope: Scope #&}:
			Reference(<Symbol>(expr->Symbol, scope).instance());
	}

	ConstantExpression VIRTUAL -> Expression { }

	MemberAccessExpression -> Expression
	{
		Lhs: Expression - std::Dynamic;
		Member: ScopeItem #\;
	}

	OperatorExpression -> Expression
	{
		Op: Operator;
		Args: Expression - std::DynVector;
	}

	CastExpression -> Expression
	{
		TYPE Kind := resolver::CastExpression::Kind;

		Method: Kind;
		Type: resolver::Type - std::Dynamic;
		Values: Expression - std::DynVector;
	}

	SizeofExpression -> ConstantExpression
	{
		Variadic: BOOL;
		Term: util::[instantiator::Type; Expression]DynUnion;
	}

	TypeofExpression -> ConstantExpression
	{
		Term: util::[instantiator::Type; Expression]DynUnion;
		Static: BOOL;
	}

	ThisExpression -> ConstantExpression { }

	NullExpression -> ConstantExpression { }

	BoolExpression -> ConstantExpression
	{
		Value: BOOL;
	}

	NumberExpression -> ConstantExpression
	{
		Number: scoper::Number;
	}

	StringExpression -> ConstantExpression
	{
		String: scoper::Text;
	}

	CharExpression -> ConstantExpression
	{
		Char: scoper::Text;
	}

	SymbolConstantExpression -> ConstantExpression
	{
		Name: scoper::Text;
	}
}