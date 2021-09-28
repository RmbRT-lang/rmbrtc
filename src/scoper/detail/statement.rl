INCLUDE "../statement.rl"
INCLUDE 'std/memory'
INCLUDE 'std/err/unimplemented'


::rlc::scoper::detail create_statement(
	position: UM,
	parsed: parser::Statement #\,
	file: src::File#&,
	parentScope: Scope \
) Statement \
{
	TYPE SWITCH(parsed)
	{
	DEFAULT:
		THROW <std::err::Unimplemented>(TYPE(parsed));
	CASE parser::AssertStatement:
		RETURN std::[AssertStatement]new(
			position,
			<parser::AssertStatement #\>(parsed),
			file,
			parentScope);
	CASE parser::BlockStatement:
		RETURN std::[BlockStatement]new(
			position,
			<parser::BlockStatement #\>(parsed),
			file,
			parentScope);
	CASE parser::IfStatement:
		RETURN std::[IfStatement]new(
			position,
			<parser::IfStatement #\>(parsed),
			file,
			parentScope);
	CASE parser::VariableStatement:
		RETURN std::[VariableStatement]new(
			position,
			<parser::VariableStatement #\>(parsed),
			file,
			parentScope);
	CASE parser::ExpressionStatement:
		RETURN std::[ExpressionStatement]new(
			position,
			<parser::ExpressionStatement #\>(parsed),
			file,
			parentScope);
	CASE parser::ReturnStatement:
		RETURN std::[ReturnStatement]new(
			position,
			<parser::ReturnStatement #\>(parsed),
			file,
			parentScope);
	CASE parser::TryStatement:
		RETURN std::[TryStatement]new(
			position,
			<parser::TryStatement #\>(parsed),
			file,
			parentScope);
	CASE parser::ThrowStatement:
		RETURN std::[ThrowStatement]new(
			position,
			<parser::ThrowStatement #\>(parsed),
			file,
			parentScope);
	CASE parser::LoopStatement:
		RETURN std::[LoopStatement]new(
			position,
			<parser::LoopStatement #\>(parsed),
			file,
			parentScope);
	CASE parser::SwitchStatement:
		RETURN std::[SwitchStatement]new(
			position,
			<parser::SwitchStatement #\>(parsed),
			file,
			parentScope);
	CASE parser::TypeSwitchStatement:
		RETURN std::[TypeSwitchStatement]new(
			position,
			<parser::TypeSwitchStatement #\>(parsed),
			file,
			parentScope);
	CASE parser::BreakStatement:
		RETURN std::[BreakStatement]new(
			position,
			<parser::BreakStatement #\>(parsed),
			file,
			parentScope);
	CASE parser::ContinueStatement:
		RETURN std::[ContinueStatement]new(
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
		PRIVATE IsVar: BOOL;
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
				variable()->set_position(++*position);
			}
			ELSE IF(parsed.is_expression())
				THIS := <<<Expression>>>(*position, parsed.expression(), file);
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
				std::delete(Val.Exp);
		}

		# is_variable() INLINE BOOL := IsVar && Val.Var;
		# variable() INLINE LocalVariable \
		{
			IF(!is_variable()) THROW;
			RETURN Val.Var;
		}

		# is_expression() INLINE BOOL := !IsVar && Val.Exp;
		# expression() INLINE Expression \
		{
			IF(!is_expression()) THROW;
			RETURN Val.Exp;
		}
		# <BOOL> INLINE := Val.Check;
	}

	AssertStatement -> Statement
	{
		Expression: std::[scoper::Expression]Dynamic;

		# FINAL variables() UM := 0;

		{
			position: UM,
			parsed: parser::AssertStatement #\,
			file: src::File#&,
			parentScope: scoper::Scope \}
		->	Statement(position, parentScope)
		:	Expression(:gc, <<<scoper::Expression>>>(position, parsed->Expression, file));
	}

	BlockStatement -> Statement
	{
		Scope: scoper::Scope;
		Statements: Statement - std::DynVector;

		# FINAL variables() UM := Statements.empty()
			? 0
			: Statements!.back()->Position + Statements!.back()->variables();

		{
			position: UM,
			parsed: parser::BlockStatement #\,
			file: src::File#&,
			parentScope: scoper::Scope \
		}->	Statement(position, parentScope)
		:	Scope(&THIS, parentScope)
		{
			p ::= Statement::Position;
			FOR(i ::= 0; i < ##parsed->Statements; i++)
			{
				Statements += :gc(<<<Statement>>>(p, parsed->Statements[i], file, &Scope));
				p += Statements!.back()->variables();
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

		# FINAL variables() UM := Else
			? Else->Position + Else->variables() - Statement::Position
			: Then->Position + Then->variables() - Statement::Position;

		{
			position: UM,
			parsed: parser::IfStatement #\,
			file: src::File#&,
			parentScope: Scope \
		}->	Statement(position, parentScope)
		:	InitScope(&THIS, parentScope),
			CondScope(&THIS, &InitScope),
			Init(&position, parsed->Init, file, &InitScope),
			Condition(&position, parsed->Condition, file, &CondScope),
			Then(:gc, <<<Statement>>>(position, parsed->Then, file, &CondScope))
		{
			position += Then->variables();
			IF(parsed->Else)
				Else := :gc(<<<Statement>>>(position, parsed->Else, file, &CondScope));
		}
	}

	VariableStatement -> Statement
	{
		Variable: LocalVariable \;
		Static: BOOL;

		# FINAL variables() UM := 1;

		{
			position: UM,
			parsed: parser::VariableStatement #\,
			file: src::File#&,
			parentScope: Scope \
		}->	Statement(position, parentScope)
		:	Static(parsed->Static)
		{
			scopeItem ::= parentScope->insert(&parsed->Variable, file);
			Variable := <<LocalVariable \>>(scopeItem);
			Variable->set_position(position+1);
		}
	}

	ExpressionStatement -> Statement
	{
		Expression: std::[scoper::Expression]Dynamic;

		# FINAL variables() UM := 0;

		{
			position: UM,
			parsed: parser::ExpressionStatement #\,
			file: src::File#&,
			parentScope: Scope \
		}->	Statement(position, parentScope)
		:	Expression(:gc, <<<scoper::Expression>>>(position, parsed->Expression, file));
	}

	ReturnStatement -> Statement
	{
		Expression: std::[scoper::Expression]Dynamic;

		# FINAL variables() UM := 0;

		# is_void() INLINE BOOL := !Expression;

		{
			position: UM,
			parsed: parser::ReturnStatement #\,
			file: src::File#&,
			parentScope: Scope \
		}->	Statement(position, parentScope)
		:	Expression(:gc, parsed->is_void()
				? NULL
				: <<<scoper::Expression>>>(position, parsed->Expression, file));
	}

	TryStatement -> Statement
	{
		Body: std::[Statement]Dynamic;
		Catches: std::[CatchStatement]Vector;
		Finally: std::[Statement]Dynamic;

		# FINAL variables() UM
		{
			vars ::= Body->variables();
			FOR(i ::= 0; i < ##Catches; i++)
				vars += Catches[i].variables();
			IF(Finally)
				vars += Finally->variables();
			RETURN vars;
		}

		# has_finally() INLINE BOOL := Finally;

		{
			position: UM,
			parsed: parser::TryStatement #\,
			file: src::File#&,
			parentScope: Scope \
		}->	Statement(position, parentScope)
		:	Body(:gc, <<<Statement>>>(position, parsed->Body, file, parentScope))
		{
			position += Body.Ptr->variables();
			FOR(i ::= 0; i < ##Catches; i++)
			{
				Catches += (position, &THIS, &parsed->Catches[i], file);
				position += Catches!.back().variables();
			}
			IF(parsed->has_finally())
				Finally := :gc(<<<Statement>>>(position, parsed->Finally, file, parentScope));
		}
	}

	CatchStatement
	{
		ExceptionScope: Scope;
		Exception: LocalVariable \;
		Body: std::[Statement]Dynamic;

		# is_void() INLINE BOOL := !Exception;
		# variables() UM := (Exception ? 1 : 0) + Body->variables();

		{
			position: UM,
			try: TryStatement \,
			parsed: parser::CatchStatement #\,
			file: src::File#&}:
			ExceptionScope(try, try->ParentScope),
			Exception(<<LocalVariable \>>(
				ExceptionScope.insert(&parsed->Exception, file))),
			Body(:gc, <<<Statement>>>(
				++position, parsed->Body, file, &ExceptionScope));
	}

	ThrowStatement -> Statement
	{
		TYPE Type := parser::ThrowStatement::Type;

		ValueType: Type;
		Value: std::[Expression]Dynamic;

		# FINAL variables() UM := 0;

		{
			position: UM,
			parsed: parser::ThrowStatement #\,
			file: src::File#&,
			parentScope: Scope \
		}->	Statement(position, parentScope)
		:	ValueType(parsed->ValueType),
			Value(:gc, parsed->Value
				? <<<Expression>>>(position, parsed->Value, file)
				: NULL);
	}

	LoopStatement -> Statement
	{
		InitScope: Scope;
		ConditionScope: Scope;

		PostCondition: BOOL;
		Initial: VarOrExp;
		Condition: VarOrExp;
		Body: std::[Statement]Dynamic;
		PostLoop: std::[Expression]Dynamic;
		Label: ControlLabel;

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
			parentScope: Scope \
		}->	Statement(position, parentScope)
		:	InitScope(&THIS, parentScope),
			ConditionScope(&THIS, &InitScope),
			PostCondition(parsed->IsPostCondition),
			Label(parsed->Label, file)
		{
			Initial := (&position, parsed->Initial, file, &InitScope);
			IF(!PostCondition)
			{
				Condition := (&position, parsed->Condition, file, &ConditionScope);
				PostLoop := (:gc, parsed->PostLoop
					? <<<Expression>>>(position, parsed->PostLoop, file)
					: NULL);
			}
			Body := :gc(<<<Statement>>>(
				position,
				parsed->Body,
				file,
				PostCondition ? &InitScope : &ConditionScope ));
			position += Body->variables();
			IF(PostCondition)
			{
				Condition := (&position, parsed->Condition, file, &ConditionScope);
				PostLoop := (:gc, parsed->PostLoop
					? <<<Expression>>>(position, parsed->PostLoop, file)
					: NULL);
			}
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

		# FINAL variables() UM
			:= Cases!.back().position() + Cases!.back().variables() - Statement::Position;

		{
			position: UM,
			parsed: parser::SwitchStatement #\,
			file: src::File#&,
			parentScope: Scope \
		}->	Statement(position, parentScope)
		:	InitScope(&THIS, parentScope),
			ValueScope(&THIS, &InitScope),
			Initial(&position, parsed->Initial, file, &InitScope),
			Value(&position, parsed->Value, file, &ValueScope),
			Label(parsed->Label, file)
		{
			FOR(i ::= 0; i < ##parsed->Cases; i++)
			{
				Cases += (position, parsed->Cases[i], file, &ValueScope);
				position += Cases!.back().variables();
			}
		}
	}

	CaseStatement
	{
		Values: Expression - std::DynVector;
		Body: std::[Statement]Dynamic;

		# is_default() INLINE BOOL := Values.empty();
		# variables() UM := Body->variables();
		# position() UM := Body->Position;

		{
			position: UM,
			parsed: parser::CaseStatement#&,
			file: src::File#&,
			parentScope: Scope \}:
			Body(:gc, <<<Statement>>>(position, parsed.Body, file, parentScope))
		{
			FOR(i ::= 0; i < ##parsed.Values; i++)
				Values += :gc(<<<Expression>>>(position, parsed.Values[i], file));
		}
	}

	TypeSwitchStatement -> Statement
	{
		Static: BOOL;
		InitScope: Scope;
		ValueScope: Scope;
		Initial: VarOrExp;
		Value: VarOrExp;
		Cases: std::[TypeCaseStatement]Vector;
		Label: ControlLabel;

		# FINAL variables() UM
			:= Cases!.back().position() + Cases!.back().variables() - Statement::Position;

		{
			position: UM,
			parsed: parser::TypeSwitchStatement #\,
			file: src::File#&,
			parentScope: Scope \
		}->	Statement(position, parentScope)
		:	Static(parsed->Static),
			InitScope(&THIS, parentScope),
			ValueScope(&THIS, &InitScope),
			Initial(&position, parsed->Initial, file, &InitScope),
			Value(&position, parsed->Value, file, &ValueScope),
			Label(parsed->Label, file)
		{
			FOR(i ::= 0; i < ##parsed->Cases; i++)
			{
				Cases += (position, parsed->Cases[i], file, &ValueScope);
				position += Cases!.back().variables();
			}
		}
	}

	TypeCaseStatement
	{
		Types: Type - std::DynVector;
		Body: std::[Statement]Dynamic;

		# is_default() INLINE BOOL := Types.empty();
		# variables() UM := Body->variables();
		# position() UM := Body->Position;

		{
			position: UM,
			parsed: parser::TypeCaseStatement#&,
			file: src::File#&,
			parentScope: Scope \}:
			Body(:gc, <<<Statement>>>(position, parsed.Body, file, parentScope))
		{
			FOR(i ::= 0; i < ##parsed.Types; i++)
				Types += :gc(<<<Type>>>(parsed.Types[i], file));
		}
	}

	BreakStatement -> Statement
	{
		Label: ControlLabel;

		# FINAL variables() UM := 0;

		{
			position: UM,
			parsed: parser::BreakStatement #\,
			file: src::File#&,
			parentScope: Scope \
		}->	Statement(position, parentScope)
		:	Label(parsed->Label, file);
	}

	ContinueStatement -> Statement
	{
		Label: ControlLabel;

		# FINAL variables() UM := 0;

		{
			position: UM,
			parsed: parser::ContinueStatement #\,
			file: src::File#&,
			parentScope: Scope \
		}->	Statement(position, parentScope)
		:	Label(parsed->Label, file);
	}
}