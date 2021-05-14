INCLUDE "../statement.rl"

INCLUDE 'std/err/unimplemented'


::rlc::scoper::detail create_statement(
	position: UM,
	parsed: parser::Statement #\,
	file: src::File#&,
	parentScope: Scope \
) Statement \
{
	SWITCH(type ::= parsed->type())
	{
	DEFAULT:
		THROW std::err::Unimplemented(type.NAME());
	CASE :assert:
		RETURN ::[AssertStatement]new(
			position,
			<parser::AssertStatement #\>(parsed),
			file,
			parentScope);
	CASE :block:
		RETURN ::[BlockStatement]new(
			position,
			<parser::BlockStatement #\>(parsed),
			file,
			parentScope);
	CASE :if:
		RETURN ::[IfStatement]new(
			position,
			<parser::IfStatement #\>(parsed),
			file,
			parentScope);
	CASE :variable:
		RETURN ::[VariableStatement]new(
			position,
			<parser::VariableStatement #\>(parsed),
			file,
			parentScope);
	CASE :expression:
		RETURN ::[ExpressionStatement]new(
			position,
			<parser::ExpressionStatement #\>(parsed),
			file,
			parentScope);
	CASE :return:
		RETURN ::[ReturnStatement]new(
			position,
			<parser::ReturnStatement #\>(parsed),
			file,
			parentScope);
	CASE :try:
		RETURN ::[TryStatement]new(
			position,
			<parser::TryStatement #\>(parsed),
			file,
			parentScope);
	CASE :throw:
		RETURN ::[ThrowStatement]new(
			position,
			<parser::ThrowStatement #\>(parsed),
			file,
			parentScope);
	CASE :loop:
		RETURN ::[LoopStatement]new(
			position,
			<parser::LoopStatement #\>(parsed),
			file,
			parentScope);
	CASE :switch:
		RETURN ::[SwitchStatement]new(
			position,
			<parser::SwitchStatement #\>(parsed),
			file,
			parentScope);
	CASE :break:
		RETURN ::[BreakStatement]new(
			position,
			<parser::BreakStatement #\>(parsed),
			file,
			parentScope);
	CASE :continue:
		RETURN ::[ContinueStatement]new(
			position,
			<parser::ContinueStatement #\>(parsed),
			file,
			parentScope);
	}
}

::rlc::scoper
{
	VarOrExp
	{
		PRIVATE UNION Value
		{
			Check: VOID *;
			Var: LocalVariable \;
			Exp: Expression \;
		}
		PRIVATE IsVar: bool;
		PRIVATE Val: Value;

		{}: IsVar(FALSE) { Val.Exp := NULL; }
		{v: LocalVariable \}: IsVar(TRUE) { Val.Var := v; }
		{v: Expression \}: IsVar(FALSE) { Val.Exp := v; }
		{
			position: UM \,
			parsed: parser::VarOrExp#&,
			file: src::File#&,
			scope: Scope \}:
			IsVar(TRUE)
		{
			IF(parsed.is_variable())
			{
				THIS := <<LocalVariable \>>(
					scope->insert(parsed.variable(), file));
				variable()->Position := (*position)++;
			}
			ELSE IF(parsed.is_expression())
				THIS := Expression::create(parsed.expression(), file);
			ELSE
				Val.Check := NULL;
		}
		{mv: VarOrExp &&}: IsVar(mv.IsVar), Val(mv.Val)
		{ mv.{}; }

		THIS:=(move: VarOrExp&&) VarOrExp&
			:= std::help::move_assign(THIS, move);
		THIS:=(p: LocalVariable \) VarOrExp&
			:= std::help::custom_assign(THIS, p);
		THIS:=(p: Expression \) VarOrExp&
			:= std::help::custom_assign(THIS, p);

		DESTRUCTOR
		{
			IF(is_expression())
				::delete(Val.Exp);
		}

		# is_variable() INLINE bool := IsVar && Val.Var;
		# variable() INLINE LocalVariable \
		{
			IF(!is_variable()) THROW;
			RETURN Val.Var;
		}

		# is_expression() INLINE bool := !IsVar && Val.Exp;
		# expression() INLINE Expression \
		{
			IF(!is_expression()) THROW;
			RETURN Val.Exp;
		}
		# <bool> INLINE := Val.Check;
	}

	AssertStatement -> Statement
	{
		Expression: std::[scoper::Expression]Dynamic;

		# FINAL type() StatementType := StatementType::assert;

		# FINAL variables() UM := 0;

		{
			position: UM,
			parsed: parser::AssertStatement #\,
			file: src::File#&,
			parentScope: scoper::Scope \}:
			Statement(position, parentScope),
			Expression(:gc, scoper::Expression::create(parsed->Expression, file));
	}

	BlockStatement -> Statement
	{
		Scope: scoper::Scope;
		Statements: std::[std::[Statement]Dynamic]Vector;

		# FINAL type() StatementType := StatementType::block;

		# FINAL variables() UM := Statements.empty()
			? 0
			: Statements.back().Ptr->Position + Statements.back().Ptr->variables();

		{
			position: UM,
			parsed: parser::BlockStatement #\,
			file: src::File#&,
			parentScope: scoper::Scope \}:
			Statement(position, parentScope),
			Scope(&THIS, parentScope)
		{
			p ::= Position;
			FOR(i ::= 0; i < parsed->Statements.size(); i++)
			{
				Statements += :gc(Statement::create(p, parsed->Statements[i], file, &Scope));
				p += Statements.back().Ptr->variables();
			}
		}
	}

	IfStatement -> Statement
	{
		InitScope: Scope;
		CondScope: Scope;

		Init: VarOrExp;
		Condition: VarOrExp;

		Then: std::[Statement]Dynamic;
		Else: std::[Statement]Dynamic;

		# FINAL type() StatementType := StatementType::if;

		# FINAL variables() UM := Else
			? Else->Position + Else->variables() - Position
			: Then->Position + Then->variables() - Position;

		{
			position: UM,
			parsed: parser::IfStatement #\,
			file: src::File#&,
			parentScope: Scope \}:
			Statement(position, parentScope),
			InitScope(&THIS, parentScope),
			CondScope(&THIS, &InitScope),
			Init(&position, parsed->Init, file, &InitScope),
			Condition(&position, parsed->Condition, file, &CondScope),
			Then(:gc, Statement::create(position, parsed->Then, file, &CondScope))
		{
			position += Then->variables();
			IF(parsed->Else)
				Else := :gc(Statement::create(position, parsed->Else, file, &CondScope));
		}
	}

	VariableStatement -> Statement
	{
		Variable: LocalVariable \;
		Static: bool;

		# FINAL type() StatementType := StatementType::variable;
		# FINAL variables() UM := 1;

		{
			position: UM,
			parsed: parser::VariableStatement #\,
			file: src::File#&,
			parentScope: Scope \}:
			Statement(position, parentScope),
			Static(parsed->Static)
		{
			scopeItem ::= parentScope->insert(&parsed->Variable, file);
			Variable := <<LocalVariable \>>(scopeItem);
			Variable->Position := position;
		}
	}

	ExpressionStatement -> Statement
	{
		Expression: std::[scoper::Expression]Dynamic;

		# FINAL type() StatementType := StatementType::expression;
		# FINAL variables() UM := 0;

		{
			position: UM,
			parsed: parser::ExpressionStatement #\,
			file: src::File#&,
			parentScope: Scope \}:
			Statement(position, parentScope),
			Expression(:gc, scoper::Expression::create(parsed->Expression, file));
	}

	ReturnStatement -> Statement
	{
		Expression: std::[scoper::Expression]Dynamic;

		# FINAL type() StatementType := StatementType::return;
		# FINAL variables() UM := 0;

		# is_void() INLINE bool := !Expression;

		{
			position: UM,
			parsed: parser::ReturnStatement #\,
			file: src::File#&,
			parentScope: Scope \}:
			Statement(position, parentScope),
			Expression(:gc, parsed->is_void()
				? NULL
				: scoper::Expression::create(parsed->Expression, file));
	}

	TryStatement -> Statement
	{
		Body: std::[Statement]Dynamic;
		Catches: std::[CatchStatement]Vector;
		Finally: std::[Statement]Dynamic;

		# FINAL type() StatementType := StatementType::try;
		# FINAL variables() UM
		{
			vars ::= Body->variables();
			FOR(i ::= 0; i < Catches.size(); i++)
				vars += Catches[i].variables();
			IF(Finally)
				vars += Finally->variables();
			RETURN vars;
		}

		# has_finally() INLINE bool := Finally;

		{
			position: UM,
			parsed: parser::TryStatement #\,
			file: src::File#&,
			parentScope: Scope \}:
			Statement(position, parentScope),
			Body(:gc, Statement::create(position, parsed->Body, file, parentScope))
		{
			position += Body.Ptr->variables();
			FOR(i ::= 0; i < Catches.size(); i++)
			{
				Catches += (position, &THIS, &parsed->Catches[i], file);
				position += Catches.back().variables();
			}
			IF(parsed->has_finally())
				Finally := :gc(Statement::create(position, parsed->Finally, file, parentScope));
		}
	}

	CatchStatement
	{
		ExceptionScope: Scope;
		Exception: LocalVariable \;
		Body: std::[Statement]Dynamic;

		# is_void() INLINE bool := !Exception;
		# variables() UM := (Exception ? 1 : 0) + Body->variables();

		{
			position: UM,
			try: TryStatement \,
			parsed: parser::CatchStatement #\,
			file: src::File#&}:
			ExceptionScope(try, try->ParentScope),
			Exception(<<LocalVariable \>>(
				ExceptionScope.insert(&parsed->Exception, file))),
			Body(:gc, Statement::create(
				++position, parsed->Body, file, &ExceptionScope));
	}

	ThrowStatement -> Statement
	{
		TYPE Type := parser::ThrowStatement::Type;

		ValueType: Type;
		Value: std::[Expression]Dynamic;

		# FINAL type() StatementType := StatementType::throw;
		# FINAL variables() UM := 0;

		{
			position: UM,
			parsed: parser::ThrowStatement #\,
			file: src::File#&,
			parentScope: Scope \}:
			Statement(position, parentScope),
			ValueType(parsed->ValueType),
			Value(:gc, parsed->Value
				? Expression::create(parsed->Value, file)
				: NULL);
	}

	LoopStatement -> Statement
	{
		InitScope: Scope;
		ConditionScope: Scope;

		PostCondition: bool;
		Initial: VarOrExp;
		Condition: VarOrExp;
		Body: std::[Statement]Dynamic;
		PostLoop: std::[Expression]Dynamic;
		Label: ControlLabel;

		# FINAL type() StatementType := StatementType::loop;
		# FINAL variables() UM
		{
			vars ::= Body->variables();
			IF(Initial.is_variable()) ++vars;
			IF(Condition.is_variable()) ++vars;
			RETURN vars;
		}

		{
			position: UM,
			parsed: parser::LoopStatement #\,
			file: src::File#&,
			parentScope: Scope \}:
			Statement(position, parentScope),
			InitScope(&THIS, parentScope),
			ConditionScope(&THIS, &InitScope),
			PostCondition(parsed->IsPostCondition),
			Initial(&position, parsed->Initial, file, &InitScope),
			PostLoop(:gc, parsed->PostLoop
				? Expression::create(parsed->PostLoop, file)
				: NULL),
			Label(parsed->Label, file)
		{
			IF(PostCondition)
				Condition := VarOrExp(&position, parsed->Condition, file, &ConditionScope);
			Body := :gc(Statement::create(position, parsed->Body, file, parentScope));
			IF(!PostCondition)
				Condition := VarOrExp(&position, parsed->Condition, file, &ConditionScope);
		}
	}

	SwitchStatement -> Statement
	{
		InitScope: Scope;
		ValueScope: Scope;
		Initial: VarOrExp;
		Value: VarOrExp;
		Cases: std::[CaseStatement]Vector;
		Label: ControlLabel;

		# FINAL type() StatementType := StatementType::switch;

		# FINAL variables() UM
			:= Cases.back().position() + Cases.back().variables() - Position;

		{
			position: UM,
			parsed: parser::SwitchStatement #\,
			file: src::File#&,
			parentScope: Scope \}:
			Statement(position, parentScope),
			InitScope(&THIS, parentScope),
			ValueScope(&THIS, &InitScope),
			Initial(&position, parsed->Initial, file, &InitScope),
			Value(&position, parsed->Value, file, &ValueScope),
			Label(parsed->Label, file)
		{
			FOR(i ::= 0; i < parsed->Cases.size(); i++)
			{
				Cases += (position, parsed->Cases[i], file, &ValueScope);
				position += Cases.back().variables();
			}
		}
	}

	CaseStatement
	{
		Values: std::[std::[Expression]Dynamic]Vector;
		Body: std::[Statement]Dynamic;

		# is_default() INLINE bool := Values.empty();
		# variables() UM := Body->variables();
		# position() UM := Body->Position;

		{
			position: UM,
			parsed: parser::CaseStatement#&,
			file: src::File#&,
			parentScope: Scope \}:
			Body(:gc, Statement::create(position, parsed.Body, file, parentScope))
		{
			FOR(i ::= 0; i < parsed.Values.size(); i++)
				Values += :gc(Expression::create(parsed.Values[i], file));
		}
	}

	BreakStatement -> Statement
	{
		Label: ControlLabel;

		# FINAL type() StatementType := StatementType::break;
		# FINAL variables() UM := 0;

		{
			position: UM,
			parsed: parser::BreakStatement #\,
			file: src::File#&,
			parentScope: Scope \}:
			Statement(position, parentScope),
			Label(parsed->Label, file);
	}

	ContinueStatement -> Statement
	{
		Label: ControlLabel;

		# FINAL type() StatementType := StatementType::continue;
		# FINAL variables() UM := 0;

		{
			position: UM,
			parsed: parser::ContinueStatement #\,
			file: src::File#&,
			parentScope: Scope \}:
			Statement(position, parentScope),
			Label(parsed->Label, file);
	}
}