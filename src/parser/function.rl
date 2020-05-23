INCLUDE "parser.rl"
INCLUDE "global.rl"
INCLUDE "member.rl"
INCLUDE "variable.rl"
INCLUDE "templatedecl.rl"
INCLUDE "statement.rl"

::rlc::parser UNION ExprOrStmt
{
	Expression: parser::Expression *;
	Statement: parser::Statement *;
}

::rlc::parser Function -> VIRTUAL ScopeItem
{
	Templates: TemplateDecl;
	Arguments: std::[GlobalVariable]Vector;
	Return: std::[Type]Dynamic;
	IsShortBody: bool;
	Body: ExprOrStmt;
	IsInline: bool;
	IsCoroutine: bool;
	Name: src::String;

	# FINAL name() src::String#& := Name;

	CONSTRUCTOR():
		IsShortBody(FALSE)
	{
		Body.Statement := NULL;
	}

	CONSTRUCTOR(
		move: Function&&):
		Templates(__cpp_std::move(move.Templates)),
		Arguments(__cpp_std::move(move.Arguments)),
		Return(__cpp_std::move(move.Return)),
		IsShortBody(move.IsShortBody),
		Body(move.Body),
		IsInline(move.IsInline),
		IsCoroutine(move.IsCoroutine)
	{
		IF(move.IsShortBody)
			move.Body.Expression := NULL;
		ELSE
			move.Body.Statement := NULL;
	}

	DESTRUCTOR
	{
		IF(IsShortBody)
		{
			IF(Body.Expression)
				::delete(Body.Expression);
		} ELSE
		{
			IF(Body.Statement)
				::delete(Body.Statement);
		}

	}

	parse(
		p: Parser &,
		allow_body: bool) bool
	{
		name: tok::Token;
		IF(!p.match_ahead(tok::Type::parentheseOpen)
		|| !p.consume(tok::Type::identifier, &name))
			RETURN FALSE;

		t: Trace(&p, "function");
		Name := name.Content;
		p.consume(NULL);

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
		IF(body.parse(p))
		{
			Body.Statement := [TYPE(body)]new(__cpp_std::move(body));
			IsShortBody := FALSE;
		} ELSE
			IsShortBody := TRUE;

		IF(IsShortBody)
		{
			p.expect(Return.Ptr
				? tok::Type::colonEqual
				: tok::Type::doubleColonEqual);

			Body.Expression := Expression::parse(p);
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
}