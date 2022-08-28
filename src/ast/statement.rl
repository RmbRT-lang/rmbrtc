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
			p: [Stage::Prev+]Statement #\,
			f: Stage::PrevFile+,
			s: Stage &
		>>> THIS-std::Dyn
		{
			TYPE SWITCH(p)
			{
			[Stage::Prev+]AssertStatement:
				= :dup(<[Stage]AssertStatement>(:transform(
					<<[Stage::Prev+]AssertStatement #&>>(*p), f, s)));
			[Stage::Prev+]DieStatement:
				= :dup(<[Stage]DieStatement>(:transform(
					<<[Stage::Prev+]DieStatement #&>>(*p), f, s)));
			[Stage::Prev+]YieldStatement:
				= :dup(<[Stage]YieldStatement>(:transform(
					<<[Stage::Prev+]YieldStatement #&>>(*p), f, s)));
			[Stage::Prev+]SleepStatement:
				= :dup(<[Stage]SleepStatement>(:transform(
					<<[Stage::Prev+]SleepStatement #&>>(*p), f, s)));
			[Stage::Prev+]BlockStatement:
				= :dup(<[Stage]BlockStatement>(:transform(
					<<[Stage::Prev+]BlockStatement #&>>(*p), f, s)));
			[Stage::Prev+]IfStatement:
				= :dup(<[Stage]IfStatement>(:transform(
					<<[Stage::Prev+]IfStatement #&>>(*p), f, s)));
			[Stage::Prev+]VariableStatement:
				= :dup(<[Stage]VariableStatement>(:transform(
					<<[Stage::Prev+]VariableStatement #&>>(*p), f, s)));
			[Stage::Prev+]ExpressionStatement:
				= :dup(<[Stage]ExpressionStatement>(:transform(
					<<[Stage::Prev+]ExpressionStatement #&>>(*p), f, s)));
			[Stage::Prev+]ReturnStatement:
				= :dup(<[Stage]ReturnStatement>(:transform(
					<<[Stage::Prev+]ReturnStatement #&>>(*p), f, s)));
			[Stage::Prev+]TryStatement:
				= :dup(<[Stage]TryStatement>(:transform(
					<<[Stage::Prev+]TryStatement #&>>(*p), f, s)));
			[Stage::Prev+]ThrowStatement:
				= :dup(<[Stage]ThrowStatement>(:transform(
					<<[Stage::Prev+]ThrowStatement #&>>(*p), f, s)));
			[Stage::Prev+]LoopStatement:
				= :dup(<[Stage]LoopStatement>(:transform(
					<<[Stage::Prev+]LoopStatement #&>>(*p), f, s)));
			[Stage::Prev+]SwitchStatement:
				= :dup(<[Stage]SwitchStatement>(:transform(
					<<[Stage::Prev+]SwitchStatement #&>>(*p), f, s)));
			[Stage::Prev+]TypeSwitchStatement:
				= :dup(<[Stage]TypeSwitchStatement>(:transform(
					<<[Stage::Prev+]TypeSwitchStatement #&>>(*p), f, s)));
			[Stage::Prev+]BreakStatement:
				= :dup(<[Stage]BreakStatement>(:transform(
					<<[Stage::Prev+]BreakStatement #&>>(*p), f, s)));
			[Stage::Prev+]ContinueStatement:
				= :dup(<[Stage]ContinueStatement>(:transform(
					<<[Stage::Prev+]ContinueStatement #&>>(*p), f, s)));
			}
		}
	}

	[Stage: TYPE] AssertStatement -> [Stage]Statement
	{
		Expression: ast::[Stage]Expression - std::Dyn;

		:transform{
			p: [Stage::Prev+]AssertStatement #&,
			f: Stage::PrevFile+,
			s: Stage &
		} -> (:transform, p, f, s):
			Expression := <<<ast::[Stage]Expression>>>(p.Expression!, f, s);
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
			s: Stage &
		} -> (:transform, p, f, s):
			Duration := <<<[Stage]Expression>>>(p.Duration!, f, s);
	}


	[Stage: TYPE] BlockStatement -> [Stage]Statement
	{
		Statements: [Stage]Statement - std::DynVec;

		:transform{
			p: [Stage::Prev+]BlockStatement #&,
			f: Stage::PrevFile+,
			s: Stage &
		} -> (:transform, p, f, s):
			Statements := :reserve(##p.Statements)
		{
			FOR(stmt ::= p.Statements.start())
				Statements += <<<[Stage]Statement>>>(stmt!, f, s);
		}
	}

	[Stage: TYPE] IfStatement -> [Stage]Statement
	{
		Label: [Stage]ControlLabel-std::Opt;

		RevealsVariable: BOOL;
		Negated: BOOL;

		Init: [Stage]VarOrExpr-std::Dyn;
		Condition: [Stage]VarOrExpr-std::Dyn;

		Then: [Stage]Statement - std::Dyn;
		Else: [Stage]Statement - std::Dyn;

		:transform{
			p: [Stage::Prev+]IfStatement #&,
			f: Stage::PrevFile+,
			s: Stage &
		} -> (:transform, p, f, s):
			RevealsVariable := p.RevealsVariable,
			Negated := p.Negated,
			Condition := <<<[Stage]VarOrExpr>>>(p.Condition!, f, s),
			Then := <<<[Stage]Statement>>>(p.Then!, f, s)
		{
			IF(p.Label)
				Label := :a(:transform(p.Label!, f, s));
			IF(p.Init)
				Init := <<<[Stage]VarOrExpr>>>(p.Init!, f, s);
			IF(p.Else)
				Else := <<<[Stage]Statement>>>(p.Then!, f, s);
		}
	}

	[Stage: TYPE] VariableStatement -> [Stage]Statement
	{
		Variable: [Stage]LocalVariable;
		Static: BOOL;

		:transform{
			p: [Stage::Prev+]VariableStatement #&,
			f: Stage::PrevFile+,
			s: Stage &
		} -> (:transform, p, f, s):
			Variable := :transform(p.Variable, f, s),
			Static := p.Static;
	}

	[Stage: TYPE] ExpressionStatement -> [Stage]Statement
	{
		Expression: ast::[Stage]Expression - std::Dyn;

		:transform{
			p: [Stage::Prev+]ExpressionStatement #&,
			f: Stage::PrevFile+,
			s: Stage &
		} -> (:transform, p, f, s):
			Expression := <<<ast::[Stage]Expression>>>(p.Expression!, f, s);
	}

	[Stage: TYPE] ReturnStatement -> [Stage]Statement
	{
		Expression: ast::[Stage]Expression - std::Dyn;

		{};

		:exp{
			e: ast::[Stage]Expression - std::Dyn
		}:	Expression(&&e);

		:transform{
			p: [Stage::Prev+]ReturnStatement #&,
			f: Stage::PrevFile+,
			s: Stage &
		} -> (:transform, p, f, s)
		{
			IF(p.Expression)
				Expression := <<<ast::[Stage]Expression>>>(p.Expression!, f, s);
		}

		# is_void() BOOL INLINE := !Expression;

	}

	[Stage: TYPE] TryStatement -> [Stage]Statement
	{
		Body: [Stage]Statement - std::Dyn;
		Catches: [Stage]CatchStatement - std::Vec;
		Finally: [Stage]Statement - std::Dyn;

		:transform{
			p: [Stage::Prev+]TryStatement #&,
			f: Stage::PrevFile+,
			s: Stage &
		} -> (:transform, p, f, s):
			Body := <<<[Stage]Statement>>>(p.Body!, f, s),
			Catches := :reserve(##p.Catches)
		{
			FOR(c ::= p.Catches.start())
				Catches += :transform(c!, f, s);
			IF(p.Finally)
				Finally := <<<[Stage]Statement>>>(p.Finally!, f, s);
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
		Exception: [Stage]TypeOrCatchVariable - std::Dyn;
		Body: [Stage]Statement - std::Dyn;

		:transform{
			p: [Stage::Prev+]CatchStatement #&,
			f: Stage::PrevFile+,
			s: Stage &
		}:
			ExceptionType := p.ExceptionType,
			Body := <<<[Stage]Statement>>>(p.Body!, f, s)
		{
			IF(p.Exception)
				Exception := <<<[Stage]TypeOrCatchVariable>>>(p.Exception, f, s);
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
		Value: [Stage]Expression-std::Dyn;

		:transform{
			p: [Stage::Prev+]ThrowStatement #&,
			f: Stage::PrevFile+,
			s: Stage &
		} -> (:transform, p, f, s):
			ValueType := p.ValueType
		{
			IF(p.Value)
				Value := <<<[Stage]Expression>>>(p.Value!, f, s);
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
		Initial: [Stage]VarOrExpr - std::Dyn;
		Condition: [Stage]VarOrExpr - std::Dyn;
		Body: [Stage]Statement-std::Dyn;
		PostLoop: [Stage]Expression-std::Dyn;
		Label: [Stage]ControlLabel-std::Opt;

		# is_post_condition() BOOL := Type == :postCondition;

		:transform{
			p: [Stage::Prev+]LoopStatement #&,
			f: Stage::PrevFile+,
			s: Stage &
		} -> (:transform, p, f, s):
			Type := p.Type,
			Body := <<<[Stage]Statement>>>(p.Body!, f, s)
		{
			IF(p.Initial)
				Initial := <<<[Stage]VarOrExpr>>>(p.Initial!, f, s);
			IF(p.Condition)
				Condition := <<<[Stage]VarOrExpr>>>(p.Condition!, f, s);
			IF(p.PostLoop)
				PostLoop := <<<[Stage]Expression>>>(p.PostLoop!, f, s);
			IF(p.Label)
				Label := :a(:transform(p.Label!, f, s));
		}
	}

	[Stage: TYPE] SwitchStatement -> [Stage]Statement
	{
		Strict: BOOL;
		Initial: [Stage]VarOrExpr - std::Dyn;
		Value: [Stage]VarOrExpr - std::Dyn;
		Cases: [Stage]CaseStatement - std::Vec;
		Label: [Stage]ControlLabel-std::Opt;

		:transform{
			p: [Stage::Prev+]SwitchStatement #&,
			f: Stage::PrevFile+,
			s: Stage &
		} -> (:transform, p, f, s):
			Strict := p.Strict,
			Value := <<<[Stage]VarOrExpr>>>(p.Value!, f, s),
			Cases := :reserve(##p.Cases)
		{
			IF(p.Initial)
				Initial := <<<[Stage]VarOrExpr>>>(p.Value!, f, s);
			FOR(c ::= p.Cases.start())
				Cases += :transform(c!, f, s);
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
			s: Stage &
		}:
			Values := :reserve(##p.Values),
			Body := <<<[Stage]Statement>>>(p.Body!, f, s)
		{
			FOR(v ::= p.Values.start())
				Values += <<<[Stage]Expression>>>(v!, f, s);
		}

		# is_default() BOOL INLINE := Values.empty();
	}

	[Stage: TYPE] TypeSwitchStatement -> [Stage]Statement
	{
		Static: BOOL;
		Initial: [Stage]VarOrExpr - std::Dyn;
		Value: [Stage]VarOrExpr - std::Dyn;
		Cases: [Stage]TypeCaseStatement - std::Vec;
		Label: [Stage]ControlLabel-std::Opt;

		:transform{
			p: [Stage::Prev+]TypeSwitchStatement #&,
			f: Stage::PrevFile+,
			s: Stage &
		} -> (:transform, p, f, s):
			Static := p.Static,
			Value := <<<[Stage]VarOrExpr>>>(p.Value!, f, s),
			Cases := :reserve(##p.Cases)
		{
			IF(p.Initial)
				Initial := <<<[Stage]VarOrExpr>>>(p.Initial!, f, s);
			FOR(c ::= p.Cases.start())
				Cases += :transform(c!, f, s);
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
			s: Stage &
		}:
			Types := :reserve(##p.Types),
			Body := <<<[Stage]Statement>>>(p.Body!, f, s)
		{
			FOR(t ::= p.Types.start())
				Types += <<<[Stage]Type>>>(t!, f, s);
		}

		# is_default() BOOL INLINE := Types.empty();
	}

	[Stage: TYPE] BreakStatement -> [Stage]Statement
	{
		Label: [Stage]ControlLabel-std::Opt;

		:transform{
			p: [Stage::Prev+]BreakStatement #&,
			f: Stage::PrevFile+,
			s: Stage &
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
			s: Stage &
		} -> (:transform, p, f, s)
		{
			IF(p.Label)
				Label := :a(:transform(p.Label!, f, s));
		}
	}
}