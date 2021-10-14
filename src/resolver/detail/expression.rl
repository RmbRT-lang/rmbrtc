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
	TYPE SWITCH(ref)
	{
	DEFAULT:
		THROW <std::err::Unimplemented>(TYPE(ref));
	scoper::SymbolExpression:
		RETURN std::[ReferenceExpression]new(<scoper::SymbolExpression #\>(ref), scope);
	scoper::NumberExpression:
		RETURN std::[NumberExpression]new(<scoper::NumberExpression #\>(ref));
	scoper::BoolExpression:
		RETURN std::[BoolExpression]new(<scoper::BoolExpression #\>(ref));
	scoper::CharExpression:
		RETURN std::[CharExpression]new(<scoper::CharExpression #\>(ref));
	scoper::StringExpression:
		RETURN std::[StringExpression]new(<scoper::StringExpression #\>(ref));
	scoper::OperatorExpression:
		{
			op ::= <scoper::OperatorExpression #\>(ref);
			SWITCH(op->Op)
			{
			DEFAULT:
				RETURN std::[OperatorExpression]new(op, scope);
			:memberReference, :memberPointer:
				RETURN std::[MemberAccessExpression]new(op, scope);
			}
		}
	scoper::ThisExpression:
		RETURN std::[ThisExpression]new();
	scoper::NullExpression:
		RETURN std::[NullExpression]new();
	scoper::CastExpression:
		RETURN std::[CastExpression]new(<scoper::CastExpression #\>(ref), scope);
	scoper::SizeofExpression:
		RETURN std::[SizeofExpression]new(<scoper::SizeofExpression #\>(ref), scope);
	scoper::TypeofExpression:
		RETURN std::[TypeofExpression]new(<scoper::TypeofExpression #\>(ref), scope);
	scoper::SymbolConstantExpression:
		RETURN std::[SymbolConstantExpression]new(<scoper::SymbolConstantExpression #\>(ref));
	}
}

::rlc::resolver
{
	ReferenceExpression -> Expression
	{
		Symbol: resolver::Symbol;

		{
			ref: scoper::SymbolExpression #\,
			scope: scoper::Scope #\
		}:	Symbol(:resolve(*scope, ref->Symbol, ref->Position));
	}

	ConstantExpression VIRTUAL -> Expression { }

	MemberAccessExpression -> Expression
	{
		Lhs: Expression - std::Dynamic;
		MemberName: scoper::String;
		MemberTemplates: TemplateArg - std::DynVector;
		IsPtr: BOOL;

		{
			ref: scoper::OperatorExpression #\,
			scope: scoper::Scope #\
		}:	Lhs(:gc(<<<Expression>>>(scope, ref->Operands[0]))),
			IsPtr(ref->Op == Operator::memberPointer)
		{
			child ::= &<scoper::SymbolChildExpression #\>(ref->Operands[1]!)->Child;
			MemberName := child->Name;
			FOR(tpl ::= child->Templates.start(); tpl; ++tpl)
				MemberTemplates += :gc(<<<TemplateArg>>>(scope, tpl!));
		}
	}

	OperatorExpression -> Expression
	{
		Op: Operator;
		Args: Expression - std::DynVector;

		{
			ref: scoper::OperatorExpression #\,
			scope: scoper::Scope #\
		}:
			Op(ref->Op)
		{
			FOR(i ::= 0; i < ##ref->Operands; i++)
				Args += :gc(<<<Expression>>>(scope, ref->Operands[i]));
		}
	}

	CastExpression -> Expression
	{
		TYPE Kind := scoper::CastExpression::Kind;

		Method: Kind;
		Type: resolver::Type - std::Dynamic;
		Values: Expression - std::DynVector;

		{
			ref: scoper::CastExpression #\,
			scope: scoper::Scope #\
		}:
			Type(:gc(<<<resolver::Type>>>(scope, ref->Type))),
			Method(ref->Method)
		{
			FOR(it ::= ref->Values.start(); it; ++it)
				Values += :gc(<<<Expression>>>(scope, it!));
		}
	}

	SizeofExpression -> ConstantExpression
	{
		Variadic: BOOL;
		Term: util::[resolver::Type; Expression]DynUnion;
		{
			ref: scoper::SizeofExpression #\,
			scope: scoper::Scope #\
		}: Variadic(ref->Variadic)
		{
			IF(ref->Term.is_first())
				Term := :gc(<<<resolver::Type>>>(scope, ref->Term.first()));
			ELSE
				Term := :gc(<<<Expression>>>(scope, ref->Term.second()));
		}
	}

	TypeofExpression -> Expression
	{
		Term: util::[resolver::Type; Expression]DynUnion;
		Static: BOOL;
		{
			ref: scoper::TypeofExpression #\,
			scope: scoper::Scope #\
		}:
			Static(ref->Static)
		{
			IF(ref->Term.is_first())
				Term := :gc(<<<resolver::Type>>>(scope, ref->Term.first()));
			ELSE
				Term := :gc(<<<Expression>>>(scope, ref->Term.second()));
		}
	}

	ThisExpression -> ConstantExpression { }

	NullExpression -> ConstantExpression { }

	BoolExpression -> ConstantExpression
	{
		Value: BOOL;

		{ref: scoper::BoolExpression #\}: Value(ref->Value);
	}

	NumberExpression -> ConstantExpression
	{
		Number: scoper::Number;
		{ref: scoper::NumberExpression #\}: Number(ref->Number);
	}

	StringExpression -> ConstantExpression
	{
		String: scoper::Text;
		{ref: scoper::StringExpression #\}: String(ref->String);
	}

	CharExpression -> ConstantExpression
	{
		Char: scoper::Text;
		{ref: scoper::CharExpression #\}: Char(ref->Char);
	}

	SymbolConstantExpression -> ConstantExpression
	{
		Name: scoper::String;
		{ref: scoper::SymbolConstantExpression #\}: Name(ref->Name);
	}
}