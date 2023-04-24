INCLUDE "statement.rl"
INCLUDE "symbol.rl"
INCLUDE "templateargs.rl"
INCLUDE "number.rl"

::rlc::instantiator::expression evaluate(
	p: ast::[resolver::Config]Expression #&,
	ctx: Context #&
) ast::[Config]Expression -std::Dyn
{
	TYPE SWITCH(p)
	{
	ast::[resolver::Config]StatementExpression:
	{
		e: ast::[Config]StatementExpression (BARE);
		e.Statement := statement::evaluate(
			<<ast::[resolver::Config]StatementExpression #&>>(p).Statement!,
			ctx);
		= :dup(&&e);
	}
	ast::[resolver::Config]ReferenceExpression:
	{
		e: ast::[Config]ReferenceExpression (BARE);
		/// Resolve any template-dependent paths.
		e.Symbol := resolve_value_symbol(
			<<ast::[resolver::Config]ReferenceExpression #&>>(p).Symbol, ctx);
		= :dup(&&e);
	}
	ast::[resolver::Config]MemberReferenceExpression:
	{
		/// resolve member of lhs' type.
		e: ast::[Config]MemberReferenceExpression (BARE);
		prev: ?& := <<ast::[resolver::Config]MemberReferenceExpression #&>>(p);
		e.Object := expression::evaluate(prev.Object!, ctx);
		lhsType ::= expression::evaluate_type(e.Object!);
		TYPE SWITCH(lhsType)
		{
		InstanceType:
		{
			desc: ?#& := <<InstanceType #&>>(lhsType!).type();
			IF:!(scope ::= <<ast::[resolver::Config]ScopeBase #*>>(desc))
				THROW <rlc::ReasonError>(prev.Position,
					"accessing member: type has no members");

			IF:!(member ::= scope->local(prev.Member.Name, 0))
				THROW <rlc::ReasonError>(prev.Member.Position,
					"no such member");
			e.Member.Type := :<>(&&lhsType);
			e.Member.Member := >>member;
			e.Member.Templates := evaluate_template_args(
				prev.Member.Templates, ctx);

			= :dup(&&e);
		}
		DEFAULT:
			THROW <rlc::ReasonError>(prev.Position,
				"accessing member: type has no members");
		}
	}
	ast::[resolver::Config]SymbolConstantExpression:
	{
		e: ast::[Config]SymbolConstantExpression (BARE);
		pr: ?#& := <<ast::[resolver::Config]SymbolConstantExpression #&>>(p);
		annotation: ast::[Config]Type-std::DynOpt;
		IF(pr.Symbol.TypeAnnotation)
			annotation := type::resolve(pr.Symbol.TypeAnnotation!, ctx);
		e.Symbol.NameType := pr.Symbol.NameType;
		e.Symbol.Identifier := pr.Symbol.Identifier;
		e.Symbol.TypeAnnotation := &&annotation;
		= :dup(&&e);
	}
	ast::[resolver::Config]NumberExpression:
	{
		e: ast::[Config]NumberExpression (BARE);
		e.Number := <<ast::[resolver::Config]NumberExpression #&>>(p).Number;
		= :dup(&&e);
	}
	ast::[resolver::Config]BoolExpression:
	{
		e: ast::[Config]BoolExpression (BARE);
		e.Value := <<ast::[resolver::Config]BoolExpression #&>>(p).Value;
		= :dup(&&e);
	}
	ast::[resolver::Config]CharExpression:
	{
		e: ast::[Config]CharExpression (BARE);
		e.Char := <<ast::[resolver::Config]CharExpression #&>>(p).Char;
		= :dup(&&e);
	}
	ast::[resolver::Config]StringExpression:
	{
		e: ast::[Config]StringExpression (BARE);
		e.String := <<ast::[resolver::Config]StringExpression#&>>(p).String;
		= :dup(&&e);
	}
	ast::[resolver::Config]OperatorExpression:
	{
		DIE; //! perform operator overload resolution (no compile time execution yet).
	}
	ast::[resolver::Config]ThisExpression:
		= :a.ast::[Config]ThisExpression (BARE);
	ast::[resolver::Config]NullExpression:
		= :a.ast::[Config]NullExpression (BARE);
	ast::[resolver::Config]BareExpression:
		= :a.ast::[Config]BareExpression (BARE);
	ast::[resolver::Config]CastExpression:
		DIE; //! need custom cast expression instead that points to a constructor instantiation.
	ast::[resolver::Config]SizeofExpression:
		DIE; //! For now just defer to C due to padding etc., probably.
	ast::[resolver::Config]TypeofExpression:
		DIE; //! need a TYPE type and value type.
	}
}

/// evaluate type and also do overload resolution etc.
::rlc::instantiator::expression evaluate_type(
	expr: ast::[Config]Expression &
) ast::[Config]Type - std::Dyn
{
	TYPE SWITCH(expr)
	{
	ast::[Config]NumberExpression:
		= :a.NumberType;
	ast::[Config]CharExpression:
	{
		b: ast::[Config]BuiltinType (BARE);
		b.Kind := :char;
		= :dup(&&b);
	}
	ast::[Config]BoolExpression:
	{
		b: ast::[Config]BuiltinType (BARE);
		b.Kind := :bool;
		= :dup(&&b);
	}
	ast::[Config]NullExpression:
		= :a.ast::[Config]Null (BARE);
	ast::[Config]BareExpression:
		= :a.ast::[Config]Bare (BARE);
	ast::[Config]StringExpression: /// CHAR#[N]
	{
		size: ast::[Config]NumberExpression(BARE);
		size.Number := :nat(##<<ast::[Config]StringExpression #&>>(expr).String);

		modifier: ast::type::[Config]Modifier (:const);
		modifier.IsArray := TRUE;
		modifier.ArraySize := :vec(:dup(&&size));

		charArray: ast::[Config]BuiltinType := :manual(ast::Primitive::char);
		charArray.Modifiers += &&modifier;

		= :dup(&&charArray);
	}
	ast::[Config]OperatorExpression:
	{
		op: ast::[Config]OperatorExpression #& := >>expr;
		op0 ::= evaluate_type(op.Operands[0]);

		IF(op0builtin ::= <<ast::[Config]BuiltinType #*>>(op0))
		{
			SWITCH(op.Op)
			{
			:logAnd, :logOr, :logNot:
				= :a.ast::[Config]BuiltinType(:manual(:bool));
			:neg, :pos, :valueOf:
				= &&op0;
			:addAssign, :subAssign, :mulAssign, :divAssign, :modAssign,
			:bitAndAssign, :bitOrAssign, :bitXorAssign,
			:shiftLeftAssign, :shiftRightAssign,
			:rotateLeftAssign, :rotateRightAssign:
				IF(op0builtin->Kind == :bool
				|| op0builtin->Modifiers && (
					op0builtin.Modifiers.end()!.IsArray
					|| op0builtin.Modifiers.end()!.Indirection != :plain))
					THROW <rlc::ReasonError>(op0!.Position, "arithmetic assignment to non-arithmetic type");
			->
			:assign: {
				IF(op0!.ReferenceType == :none
				|| op0!.Modifiers && op0!.Modifiers.end()!.Modifier.Qualifier == )
					THROW <rlc::ReasonError>(op0!.Position, "assignment to constant");
			}
			}
		}
	}
	}
}