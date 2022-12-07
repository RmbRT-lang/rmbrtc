INCLUDE "expression.rl"
INCLUDE "variable.rl"
INCLUDE "controllabel.rl"
INCLUDE "exprorstatement.rl"

INCLUDE 'std/vector'
INCLUDE 'std/memory'

::rlc::ast
{
	[Stage: TYPE] Statement VIRTUAL -> [Stage]ExprOrStatement
	{
		:transform{
			p: [Stage::Prev+]Statement #&,
			f: Stage::PrevFile+,
			s: Stage &
		};

		<<<
			p: [Stage::Prev+]Statement #&,
			f: Stage::PrevFile+,
			s: Stage &,
			parent: [Stage]ScopeBase \
		>>> THIS-std::Dyn
		{
			TYPE SWITCH(p)
			{
			[Stage::Prev+]AssertStatement:
				= :a.[Stage]AssertStatement(:transform(>>p, f, s, parent));
			[Stage::Prev+]DieStatement:
				= :a.[Stage]DieStatement(:transform(>>p, f, s));
			[Stage::Prev+]YieldStatement:
				= :a.[Stage]YieldStatement(:transform(>>p, f, s));
			[Stage::Prev+]SleepStatement:
				= :a.[Stage]SleepStatement(:transform(>>p, f, s, parent));
			[Stage::Prev+]BlockStatement:
				= :a.[Stage]BlockStatement(:transform(>>p, f, s, parent));
			[Stage::Prev+]IfStatement:
				= :a.[Stage]IfStatement(:transform(>>p, f, s, parent));
			[Stage::Prev+]VariableStatement:
				= :a.[Stage]VariableStatement(:transform(>>p, f, s, parent));
			[Stage::Prev+]ExpressionStatement:
				= :a.[Stage]ExpressionStatement(:transform(>>p, f, s, parent));
			[Stage::Prev+]ReturnStatement:
				= :a.[Stage]ReturnStatement(:transform(>>p, f, s, parent));
			[Stage::Prev+]TryStatement:
				= :a.[Stage]TryStatement(:transform(>>p, f, s, parent));
			[Stage::Prev+]ThrowStatement:
				= :a.[Stage]ThrowStatement(:transform(>>p, f, s, parent));
			[Stage::Prev+]LoopStatement:
				= :a.[Stage]LoopStatement(:transform(>>p, f, s, parent));
			[Stage::Prev+]SwitchStatement:
				= :a.[Stage]SwitchStatement(:transform(>>p, f, s, parent));
			[Stage::Prev+]TypeSwitchStatement:
				= :a.[Stage]TypeSwitchStatement(:transform(>>p, f, s, parent));
			[Stage::Prev+]BreakStatement:
				= :a.[Stage]BreakStatement(:transform(>>p, f, s, parent));
			[Stage::Prev+]ContinueStatement:
				= :a.[Stage]ContinueStatement(:transform(>>p, f, s, parent));
			}
		}
	}

	[Stage: TYPE] AssertStatement -> [Stage]Statement
	{
		Expression: ast::[Stage]Expression - std::Dyn;

		:transform{
			p: [Stage::Prev+]AssertStatement #&,
			f: Stage::PrevFile+,
			s: Stage &,
			parent: [Stage]ScopeBase \
		} -> (:transform, p, f, s):
			Expression := :make(p.Expression!, f, s, parent);
	}

	[Stage: TYPE] DieStatement -> [Stage]Statement
	{
		Message: ast::[Stage]StringExpression - std::Opt;

		:transform{
			p: [Stage::Prev+]DieStatement #&,
			f: Stage::PrevFile+,
			s: Stage &
		} -> (:transform, p, f, s)
		{
			IF(p.Message)
				Message := :a(:transform(p.Message!, f, s));
		}
	}

	[Stage: TYPE] YieldStatement -> [Stage]Statement {
		:transform{
			p: [Stage::Prev+]YieldStatement #&,
			f: Stage::PrevFile+,
			s: Stage &
		} -> (:transform, p, f, s);
	}
	[Stage: TYPE] SleepStatement -> [Stage]Statement
	{
		Duration: [Stage]Expression - std::Dyn;

		:transform{
			p: [Stage::Prev+]SleepStatement #&,
			f: Stage::PrevFile+,
			s: Stage &,
			parent: [Stage]ScopeBase \
		} -> (:transform, p, f, s):
			Duration := :make(p.Duration!, f, s, parent);
	}


	[Stage: TYPE] BlockStatement -> [Stage]Statement
	{
		Statements: [Stage]Statement - std::DynVec;

		:transform{
			p: [Stage::Prev+]BlockStatement #&,
			f: Stage::PrevFile+,
			s: Stage &,
			parent: [Stage]ScopeBase \
		} -> (:transform, p, f, s):
			Statements := :reserve(##p.Statements)
		{
			FOR(stmt ::= p.Statements.start())
				Statements += :make(stmt!, f, s, parent);
		}
	}

	[Stage: TYPE] IfStatement -> [Stage]Statement
	{
		Label: [Stage]ControlLabel-std::Opt;

		RevealsVariable: BOOL;
		Negated: BOOL;

		Init: [Stage]VarOrExpr-std::DynOpt;
		Condition: [Stage]VarOrExpr-std::Dyn;

		Then: [Stage]Statement - std::Dyn;
		Else: [Stage]Statement - std::DynOpt;

		:transform{
			p: [Stage::Prev+]IfStatement #&,
			f: Stage::PrevFile+,
			s: Stage &,
			parent: [Stage]ScopeBase \
		} -> (:transform, p, f, s):
			RevealsVariable := p.RevealsVariable,
			Negated := p.Negated,
			Condition := :make(p.Condition!, f, s, parent),
			Then := :make(p.Then!, f, s, parent)
		{
			IF(p.Label)
				Label := :a(:transform(p.Label!, f, s));
			IF(p.Init)
				Init := :make(p.Init!, f, s, parent);
			IF(p.Else)
				Else := :make(p.Then!, f, s, parent);
		}
	}

	[Stage: TYPE] VariableStatement -> [Stage]Statement
	{
		Variable: [Stage]LocalVariable;
		Static: BOOL;

		:transform{
			p: [Stage::Prev+]VariableStatement #&,
			f: Stage::PrevFile+,
			s: Stage &,
			parent: [Stage]ScopeBase \
		} -> (:transform, p, f, s):
			Variable := :transform(p.Variable, f, s, parent),
			Static := p.Static;
	}

	[Stage: TYPE] ExpressionStatement -> [Stage]Statement
	{
		Expression: ast::[Stage]Expression - std::Dyn;

		:transform{
			p: [Stage::Prev+]ExpressionStatement #&,
			f: Stage::PrevFile+,
			s: Stage &,
			parent: [Stage]ScopeBase \
		} -> (:transform, p, f, s):
			Expression := :make(p.Expression!, f, s, parent);
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
			f: Stage::PrevFile+,
			s: Stage &,
			parent: [Stage]ScopeBase \
		} -> (:transform, p, f, s)
		{
			IF(p.Expression)
				Expression := :make(p.Expression!, f, s, parent);
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
			f: Stage::PrevFile+,
			s: Stage &,
			parent: [Stage]ScopeBase \
		} -> (:transform, p, f, s):
			Body := :make(p.Body!, f, s, parent),
			Catches := :reserve(##p.Catches)
		{
			FOR(c ::= p.Catches.start())
				Catches += :transform(c!, f, s, parent);
			IF(p.Finally)
				Finally := :make(p.Finally!, f, s, parent);
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
		Exception: [Stage]TypeOrCatchVariable - std::DynOpt;
		Body: [Stage]Statement - std::Dyn;

		:transform{
			p: [Stage::Prev+]CatchStatement #&,
			f: Stage::PrevFile+,
			s: Stage &,
			parent: [Stage]ScopeBase \
		}:
			ExceptionType := p.ExceptionType,
			Body := :make(p.Body!, f, s, parent)
		{
			IF(p.Exception)
				Exception := :make(p.Exception!, f, s, parent);
		}
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
			f: Stage::PrevFile+,
			s: Stage &,
			parent: [Stage]ScopeBase \
		} -> (:transform, p, f, s):
			ValueType := p.ValueType
		{
			IF(p.Value)
				Value := :make(p.Value!, f, s, parent);
		}
	}

	ENUM LoopType
	{
		condition,
		postCondition,
		range,
		reverseRange
	}

	[Stage: TYPE] LoopStatement -> [Stage]Statement
	{
		Type: LoopType;
		Initial: [Stage]VarOrExpr - std::DynOpt;
		Condition: [Stage]VarOrExpr - std::DynOpt;
		Body: [Stage]Statement-std::Dyn;
		PostLoop: [Stage]Expression-std::DynOpt;
		Label: [Stage]ControlLabel-std::Opt;

		# is_post_condition() BOOL := Type == :postCondition;

		:transform{
			p: [Stage::Prev+]LoopStatement #&,
			f: Stage::PrevFile+,
			s: Stage &,
			parent: [Stage]ScopeBase \
		} -> (:transform, p, f, s):
			Type := p.Type,
			Body := :make(p.Body!, f, s, parent)
		{
			IF(p.Initial)
				Initial := :make(p.Initial!, f, s, parent);
			IF(p.Condition)
				Condition := :make(p.Condition!, f, s, parent);
			IF(p.PostLoop)
				PostLoop := :make(p.PostLoop!, f, s, parent);
			IF(p.Label)
				Label := :a(:transform(p.Label!, f, s));
		}
	}

	[Stage: TYPE] SwitchStatement -> [Stage]Statement
	{
		Strict: BOOL;
		Initial: [Stage]VarOrExpr - std::DynOpt;
		Value: [Stage]VarOrExpr - std::Dyn;
		Cases: [Stage]CaseStatement - std::Vec;
		Label: [Stage]ControlLabel-std::Opt;

		:transform{
			p: [Stage::Prev+]SwitchStatement #&,
			f: Stage::PrevFile+,
			s: Stage &,
			parent: [Stage]ScopeBase \
		} -> (:transform, p, f, s):
			Strict := p.Strict,
			Value := :make(p.Value!, f, s, parent),
			Cases := :reserve(##p.Cases)
		{
			IF(p.Initial)
				Initial := :make(p.Value!, f, s, parent);
			FOR(c ::= p.Cases.start())
				Cases += :transform(c!, f, s, parent);
			IF(p.Label)
				Label := :a(:transform(p.Label!, f, s));
		}
	}

	[Stage: TYPE] CaseStatement
	{
		Values: [Stage]Expression - std::DynVec;
		Body: [Stage]Statement-std::Dyn;

		:transform{
			p: [Stage::Prev+]CaseStatement #&,
			f: Stage::PrevFile+,
			s: Stage &,
			parent: [Stage]ScopeBase \
		}:
			Values := :reserve(##p.Values),
			Body := :make(p.Body!, f, s, parent)
		{
			FOR(v ::= p.Values.start())
				Values += :make(v!, f, s, parent);
		}

		# is_default() BOOL INLINE := Values.empty();
	}

	[Stage: TYPE] TypeSwitchStatement -> [Stage]Statement
	{
		Static: BOOL;
		Strict: BOOL;
		Initial: [Stage]VarOrExpr - std::DynOpt;
		Value: [Stage]VarOrExpr - std::Dyn;
		Cases: [Stage]TypeCaseStatement - std::Vec;
		Label: [Stage]ControlLabel-std::Opt;

		:transform{
			p: [Stage::Prev+]TypeSwitchStatement #&,
			f: Stage::PrevFile+,
			s: Stage &,
			parent: [Stage]ScopeBase \
		} -> (:transform, p, f, s):
			Static := p.Static,
			Strict := p.Strict,
			Value := :make(p.Value!, f, s, parent),
			Cases := :reserve(##p.Cases)
		{
			IF(p.Initial)
				Initial := :make(p.Initial!, f, s, parent);
			FOR(c ::= p.Cases.start())
				Cases += :transform(c!, f, s, parent);
			IF(p.Label)
				Label := :a(:transform(p.Label!, f, s));
		}
	}

	[Stage: TYPE] TypeCaseStatement
	{
		Types: [Stage]Type - std::DynVec;
		Body: [Stage]Statement-std::Dyn;

		:transform{
			p: [Stage::Prev+]TypeCaseStatement #&,
			f: Stage::PrevFile+,
			s: Stage &,
			parent: [Stage]ScopeBase \
		}:
			Types := :reserve(##p.Types),
			Body := <<<[Stage]Statement>>>(p.Body!, f, s, parent)
		{
			FOR(t ::= p.Types.start())
				Types += <<<[Stage]Type>>>(t!, f, s, parent);
		}

		# is_default() BOOL INLINE := Types.empty();
	}

	[Stage: TYPE] BreakStatement -> [Stage]Statement
	{
		Label: [Stage]ControlLabel-std::Opt;

		:transform{
			p: [Stage::Prev+]BreakStatement #&,
			f: Stage::PrevFile+,
			s: Stage &,
			parent: [Stage]ScopeBase \
		} -> (:transform, p, f, s)
		{
			IF(p.Label)
				Label := :a(:transform(p.Label!, f, s));
		}
	}

	[Stage: TYPE] ContinueStatement -> [Stage]Statement
	{
		Label: [Stage]ControlLabel-std::Opt;

		:transform{
			p: [Stage::Prev+]ContinueStatement #&,
			f: Stage::PrevFile+,
			s: Stage &,
			parent: [Stage]ScopeBase \
		} -> (:transform, p, f, s)
		{
			IF(p.Label)
				Label := :a(:transform(p.Label!, f, s));
		}
	}
}