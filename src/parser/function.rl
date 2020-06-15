INCLUDE "parser.rl"
INCLUDE "global.rl"
INCLUDE "member.rl"
INCLUDE "variable.rl"
INCLUDE "templatedecl.rl"
INCLUDE "statement.rl"

INCLUDE 'std/tags'

::rlc::parser::detail UNION ExprOrStmt
{
	Expression: parser::Expression *;
	Statement: parser::Statement *;
}

::rlc::parser ExprOrStmt -> ::std::[ExprOrStmt]AutoMoveAssign
{
	Value: detail::ExprOrStmt;
	IsStmt: bool;

	std::NoCopy;

	CONSTRUCTOR():
		IsStmt(FALSE)
	{
		Value.Expression := NULL;
	}
	CONSTRUCTOR(move: ExprOrStmt &&):
		Value(move.Value),
		IsStmt(move.IsStmt)
	{
		move.CONSTRUCTOR();
	}

	DESTRUCTOR
	{
		IF(IsStmt)
		{
			IF(Value.Statement)
				::delete(Value.Statement);
		} ELSE
			IF(Value.Expression)
				::delete(Value.Expression);
	}
}

::rlc::parser Function -> VIRTUAL ScopeItem
{
	Arguments: std::[GlobalVariable]Vector;
	Return: std::[Type]Dynamic;
	Body: ExprOrStmt;
	IsInline: bool;
	IsCoroutine: bool;
	Name: src::String;

	# FINAL name() src::String#& := Name;

	parse(
		p: Parser &,
		allow_body: bool) bool
	{
		IF(!p.match_ahead(tok::Type::parentheseOpen)
		|| !p.consume(tok::Type::identifier, &Name))
			RETURN FALSE;

		t: Trace(&p, "function");
		p.expect(tok::Type::parentheseOpen);

		IF(!p.consume(tok::Type::parentheseClose))
		{
			DO(arg: GlobalVariable)
			{
				IF(!arg.parse_fn_arg(p))
					p.fail("expected argument");
				Arguments.push_back(__cpp_std::move(arg));
			} WHILE(p.consume(tok::Type::comma))
			p.expect(tok::Type::parentheseClose);
		}

		IsInline := p.consume(tok::Type::inline);
		IsCoroutine := p.consume(tok::Type::at);

		Return := Type::parse(p);
		IF(!allow_body)
			IF(!Return.Ptr)
				p.fail("expected return type");
			ELSE
			{
				p.expect(tok::Type::semicolon);
				RETURN TRUE;
			}

		body: BlockStatement;
		IF(Body.IsStmt := body.parse(p))
		{
			Body.Value.Statement := std::dup(__cpp_std::move(body));
		} ELSE
		{
			p.expect(Return.Ptr
				? tok::Type::colonEqual
				: tok::Type::doubleColonEqual);

			Body.Value.Expression := Expression::parse(p);
			p.expect(tok::Type::semicolon);
		}

		RETURN TRUE;
	}
}

::rlc::parser GlobalFunction -> Global, Function
{
	# FINAL type() Global::Type := Global::Type::function;
	parse(p: Parser&) INLINE bool := Function::parse(p, TRUE);
}

::rlc::parser MemberFunction -> Member, Function
{
	# FINAL type() Member::Type := Member::Type::function;
	parse(p: Parser&) INLINE bool := Function::parse(p, TRUE);
}