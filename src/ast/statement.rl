INCLUDE "expression.rl"
INCLUDE "variable.rl"
INCLUDE "controllabel.rl"
INCLUDE "exprorstatement.rl"

INCLUDE 'std/vector'
INCLUDE 'std/memory'

::rlc::ast
{
	[Stage: TYPE] Statement VIRTUAL -> [Stage]ExprOrStatement, CodeObject
	{
		Parent: THIS *;

		:transform{
			p: [Stage::Prev+]Statement #&,
			ctx: Stage::Context+ #&
		} -> (), (p):
			Parent := ctx.Stmt ?? ctx.Stmt! : NULL;

		<<<
			p: [Stage::Prev+]Statement #&,
			ctx: Stage::Context+ #&
		>>> THIS-std::Dyn
		{
			TYPE SWITCH(p)
			{
			[Stage::Prev+]AssertStatement:
				= :a.[Stage]AssertStatement(:transform(>>p, ctx));
			[Stage::Prev+]DieStatement:
				= :a.[Stage]DieStatement(:transform(>>p, ctx));
			[Stage::Prev+]YieldStatement:
				= :a.[Stage]YieldStatement(:transform(>>p, ctx));
			[Stage::Prev+]SleepStatement:
				= :a.[Stage]SleepStatement(:transform(>>p, ctx));
			[Stage::Prev+]BlockStatement:
				= :a.[Stage]BlockStatement(:transform(>>p, ctx));
			[Stage::Prev+]IfStatement:
				= :a.[Stage]IfStatement(:transform(>>p, ctx));
			[Stage::Prev+]VariableStatement:
				= :a.[Stage]VariableStatement(:transform(>>p, ctx));
			[Stage::Prev+]ExpressionStatement:
				= :a.[Stage]ExpressionStatement(:transform(>>p, ctx));
			[Stage::Prev+]ReturnStatement:
				= :a.[Stage]ReturnStatement(:transform(>>p, ctx));
			[Stage::Prev+]TryStatement:
				= :a.[Stage]TryStatement(:transform(>>p, ctx));
			[Stage::Prev+]ThrowStatement:
				= :a.[Stage]ThrowStatement(:transform(>>p, ctx));
			[Stage::Prev+]LoopStatement:
				= :a.[Stage]LoopStatement(:transform(>>p, ctx));
			[Stage::Prev+]SwitchStatement:
				= :a.[Stage]SwitchStatement(:transform(>>p, ctx));
			[Stage::Prev+]TypeSwitchStatement:
				= :a.[Stage]TypeSwitchStatement(:transform(>>p, ctx));
			[Stage::Prev+]BreakStatement:
				= :a.[Stage]BreakStatement(:transform(>>p, ctx));
			[Stage::Prev+]ContinueStatement:
				= :a.[Stage]ContinueStatement(:transform(>>p, ctx));
			}
		}
	}

	[Stage: TYPE] LabelledStatement VIRTUAL
	{
		Label: [Stage]ControlLabel - std::Opt;

		:transform{
			p: [Stage::Prev+]LabelledStatement #&,
			ctx: Stage::Context+ #&
		}:
			Label := :if(p.Label, :transform(p.Label.ok(), ctx));
	}

	[Stage: TYPE] AssertStatement -> [Stage]Statement
	{
		Expression: ast::[Stage]Expression - std::Dyn;

		:transform{
			p: [Stage::Prev+]AssertStatement #&,
			ctx: Stage::Context+ #&
		} -> (:transform, p, ctx):
			Expression := :make(p.Expression!, ctx);
	}

	[Stage: TYPE] DieStatement -> [Stage]Statement
	{
		Message: ast::[Stage]StringExpression - std::Opt;

		:transform{
			p: [Stage::Prev+]DieStatement #&,
			ctx: Stage::Context+ #&
		} -> (:transform, p, ctx)
		{
			IF(p.Message)
				Message := :a(:transform(p.Message!, ctx));
		}
	}

	[Stage: TYPE] YieldStatement -> [Stage]Statement {
		:transform{
			p: [Stage::Prev+]YieldStatement #&,
			ctx: Stage::Context+ #&
		} -> (:transform, p, ctx);
	}

	[Stage: TYPE] SleepStatement -> [Stage]Statement
	{
		Duration: [Stage]Expression - std::Dyn;

		:transform{
			p: [Stage::Prev+]SleepStatement #&,
			ctx: Stage::Context+ #&
		} -> (:transform, p, ctx):
			Duration := :make(p.Duration!, ctx);
	}


	[Stage: TYPE] BlockStatement -> [Stage]Statement, [Stage]ScopeBase
	{
		Statements: [Stage]Statement - std::DynVec;

		:transform{
			p: [Stage::Prev+]BlockStatement #&,
			ctx: Stage::Context+ #&
		} -> (:transform, p, ctx), (:childOf, ctx.Parent):
			Statements := :reserve(##p.Statements)
		{
			c #::= ctx.in_stmt(&p, &THIS).in_parent(&p, &THIS);
			FOR(stmt ::= p.Statements.start())
				Statements += :make(stmt!, c);
		}

		#? FINAL scope_item(Stage::Name #&) [Stage]ScopeItem #? * := NULL;
		#? FINAL local(name: Stage::Name #&, pos: LocalPosition) [Stage]ScopeItem #? *
		{
			FOR(stmt ::= Statements.end(); --)
				IF(var ::= <<[Stage]VariableStatement #?*>>(&stmt!))
				{
					IF(var->Variable.visible(pos) && var->Variable.Name == name)
						= &var->Variable;
				} ELSE IF(if ::= <<[Stage]IfStatement #?*>>(&stmt!))
					IF(if->RevealsVariable)
					{
						IF(init ::= <<[Stage]LocalVariable #?*>>(if->Init.ptr()))
							IF(init->visible(pos) && init->Name == name)
								= init;
						IF(cond ::= <<[Stage]LocalVariable #?*>>(if->Condition.ptr()))
							IF(cond->visible(pos) && cond->Name == name)
								= cond;
					}
			= NULL;
		}
	}

	[Stage: TYPE] IfStatement ->
		[Stage]Statement,
		[Stage]LabelledStatement
	{
		RevealsVariable: BOOL;
		Negated: BOOL;

		Init: [Stage]VarOrExpr - [Stage]DynOptScoped;
		Condition: [Stage]VarOrExpr - [Stage]DynScoped;

		Then: [Stage]Statement - std::Dyn;
		Else: [Stage]Statement - std::DynOpt;

		:transform{
			p: [Stage::Prev+]IfStatement #&,
			ctx: Stage::Context+ #&
		} -> (:transform, p, ctx), (:transform, p, ctx):
			RevealsVariable := p.RevealsVariable,
			Negated := p.Negated,
			Init := :make_if(p.Init, ctx),
			Condition := :make(p.Condition, ctx.in_parent(&p.Init, &Init)),
			Then := :make(p.Then!,
				ctx.in_stmt(&p, &THIS).in_parent(&p.Condition, &Condition)),
			Else := :make_if(p.Else, p.Else.ok(),
				ctx.in_stmt(&p, &THIS).in_parent(&p.Condition, &Condition));
	}

	[Stage: TYPE] VariableStatement -> [Stage]Statement
	{
		Variable: [Stage]LocalVariable;
		Static: BOOL;

		:transform{
			p: [Stage::Prev+]VariableStatement #&,
			ctx: Stage::Context+ #&
		} -> (:transform, p, ctx):
			Variable := :transform(p.Variable, ctx),
			Static := p.Static;
	}

	[Stage: TYPE] ExpressionStatement -> [Stage]Statement
	{
		Expression: ast::[Stage]Expression - std::Dyn;

		:transform{
			p: [Stage::Prev+]ExpressionStatement #&,
			ctx: Stage::Context+ #&
		} -> (:transform, p, ctx):
			Expression := :make(p.Expression!, ctx);
	}

	[Stage: TYPE] ReturnStatement -> [Stage]Statement
	{
		Expression: ast::[Stage]Expression - std::DynOpt;

		{};

		:exp{
			e: ast::[Stage]Expression - std::Dyn
		}:	Expression(&&e);

		:transform{
			p: [Stage::Prev+]ReturnStatement #&,
			ctx: Stage::Context+ #&
		} -> (:transform, p, ctx)
		{
			IF(p.Expression)
				Expression := :make(p.Expression!, ctx);
		}

		# is_void() BOOL INLINE := !Expression;
	}

	[Stage: TYPE] TryStatement -> [Stage]Statement
	{
		Body: [Stage]Statement - std::Dyn;
		Catches: [Stage]CatchStatement - std::Vec;
		Finally: [Stage]Statement - std::DynOpt;

		:transform{
			p: [Stage::Prev+]TryStatement #&,
			ctx: Stage::Context+ #&
		} -> (:transform, p, ctx):
			Body := :make(p.Body!, ctx),
			Catches := :reserve(##p.Catches)
		{
			FOR(c ::= p.Catches.start())
				Catches += :transform(c!, ctx);
			IF(p.Finally)
				Finally := :make(p.Finally!, ctx);
		}

		# has_finally() BOOL INLINE := Finally;
	}

	[Stage: TYPE] CatchStatement
	{
		ENUM Type
		{
			void,
			any,
			specific
		}

		ExceptionType: Type;
		Exception: [Stage]TypeOrCatchVariable - [Stage]DynOptScoped;
		Body: [Stage]Statement - std::Dyn;

		:transform{
			p: [Stage::Prev+]CatchStatement #&,
			ctx: Stage::Context+ #&
		}:
			ExceptionType := p.ExceptionType,
			Exception := :make_if(p.Exception, ctx),
			Body := :make(p.Body!, ctx.in_parent(&p.Exception, &Exception));
	}

	[Stage: TYPE] ThrowStatement -> [Stage]Statement
	{
		ENUM Type
		{
			rethrow,
			void,
			value
		}

		ValueType: Type;
		Value: [Stage]Expression-std::DynOpt;

		:transform{
			p: [Stage::Prev+]ThrowStatement #&,
			ctx: Stage::Context+ #&
		} -> (:transform, p, ctx):
			ValueType := p.ValueType
		{
			IF(p.Value)
				Value := :make(p.Value!, ctx);
		}
	}

	ENUM LoopType
	{
		condition,
		postCondition,
		range,
		reverseRange
	}

	[Stage: TYPE] LoopStatement ->
		[Stage]Statement,
		[Stage]LabelledStatement
	{
		Type: LoopType;
		Initial: [Stage]VarOrExpr - ast::[Stage]DynOptScoped;
		Condition: [Stage]VarOrExpr - ast::[Stage]DynOptScoped;
		Body: [Stage]Statement-std::Dyn;
		PostLoop: [Stage]Expression-std::DynOpt;

		# is_post_condition() BOOL := Type == :postCondition;

		:transform{
			p: [Stage::Prev+]LoopStatement #&,
			ctx: Stage::Context+ #&
		} -> (:transform, p, ctx), (:transform, p, ctx):
			Type := p.Type,
			Initial := :make_if(p.Initial, ctx),
			Condition := :make_if(p.Condition, ctx.in_parent(&p.Initial, &Initial)),
			Body := :make(p.Body!,
				ctx.in_stmt(&p, &THIS).in_parent(&p.Condition, &Condition)),
			PostLoop := :make_if(p.PostLoop,
				p.PostLoop.ok(), ctx.in_parent(&p.Initial, &Initial));
	}

	[Stage: TYPE] SwitchStatement ->
		[Stage]Statement,
		[Stage]LabelledStatement
	{
		Strict: BOOL;
		Initial: [Stage]VarOrExpr - ast::[Stage]DynOptScoped;
		Value: [Stage]VarOrExpr - ast::[Stage]DynScoped;
		Cases: [Stage]CaseStatement - std::Vec;

		:transform{
			p: [Stage::Prev+]SwitchStatement #&,
			ctx: Stage::Context+ #&
		} -> (:transform, p, ctx), (:transform, p, ctx):
			Strict := p.Strict,
			Initial := :make_if(p.Initial, ctx),
			Value := :make(p.Value, ctx.in_parent(&p.Initial, &Initial)),
			Cases := :reserve(##p.Cases)
		{
			_ctx ::= ctx.in_stmt(&p, &THIS).in_parent(&p.Value, &Value);
			FOR(c ::= p.Cases.start())
				Cases += :transform(c!, _ctx);
		}
	}

	[Stage: TYPE] CaseStatement
	{
		Values: [Stage]Expression - std::DynVec;
		Body: [Stage]Statement-std::Dyn;

		:transform{
			p: [Stage::Prev+]CaseStatement #&,
			ctx: Stage::Context+ #&
		}:
			Values := :reserve(##p.Values),
			Body := :make(p.Body!, ctx)
		{
			FOR(v ::= p.Values.start())
				Values += :make(v!, ctx);
		}

		# is_default() BOOL INLINE := Values.empty();
	}

	[Stage: TYPE] TypeSwitchStatement -> [Stage]Statement
	{
		Static: BOOL;
		Strict: BOOL;
		Initial: [Stage]VarOrExpr - ast::[Stage]DynOptScoped;
		Value: [Stage]VarOrExpr - ast::[Stage]DynScoped;
		Cases: [Stage]TypeCaseStatement - std::Vec;
		Label: [Stage]ControlLabel-std::Opt;

		:transform{
			p: [Stage::Prev+]TypeSwitchStatement #&,
			ctx: Stage::Context+ #&
		} -> (:transform, p, ctx):
			Static := p.Static,
			Strict := p.Strict,
			Initial := :make_if(p.Initial, ctx),
			Value := :make(p.Value, ctx.in_parent(&p.Initial, &Initial)),
			Cases := :reserve(##p.Cases)
		{
			FOR(c ::= p.Cases.start())
				Cases += :transform(c!, ctx.in_parent(&p.Value, &Value));
			IF(p.Label)
				Label := :a(:transform(p.Label!, ctx));
		}
	}

	[Stage: TYPE] TypeCaseStatement
	{
		Types: [Stage]Type - std::DynVec;
		Body: [Stage]Statement-std::Dyn;

		:transform{
			p: [Stage::Prev+]TypeCaseStatement #&,
			ctx: Stage::Context+ #&
		}:
			Types := :reserve(##p.Types),
			Body := <<<[Stage]Statement>>>(p.Body!, ctx)
		{
			FOR(t ::= p.Types.start())
				Types += <<<[Stage]Type>>>(t!, ctx);
		}

		# is_default() BOOL INLINE := Types.empty();
	}

	[Stage: TYPE] BreakStatement -> [Stage]Statement
	{
		Label: Stage::ControlLabelReference+ -std::Opt;

		:transform{
			p: [Stage::Prev+]BreakStatement #&,
			ctx: Stage::Context+ #&
		} -> (:transform, p, ctx):
			Label := ctx.transform_control_label_reference(p.Label, p.Position);
	}

	[Stage: TYPE] ContinueStatement -> [Stage]Statement
	{
		Label: Stage::ControlLabelReference+ -std::Opt;

		:transform{
			p: [Stage::Prev+]ContinueStatement #&,
			ctx: Stage::Context+ #&
		} -> (:transform, p, ctx):
			Label := ctx.transform_control_label_reference(p.Label, p.Position);
	}
}