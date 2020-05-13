INCLUDE "parser.rl"
INCLUDE "scopeentry.rl"
INCLUDE "variable.rl"
INCLUDE "templatedecl.rl"

::rlc::parser UNION ExprOrStmt
{
	Expression: parser::Expression *;
	Statement: int*;
}

::rlc::parser Function -> ScopeEntry
{
	Templates: TemplateDecl;
	Arguments: std::[Variable]Vector;
	Return: std::[Type]Dynamic;
	IsShortBody: bool;
	Body: ExprOrStmt;
	IsInline: bool;
	IsCoroutine: bool;

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

	# FINAL type() ScopeEntryType := ScopeEntryType::function;

	parse(
		p: Parser &,
		allow_body: bool) bool
	{
		name: tok::Token;
		IF(!p.match_ahead(tok::Type::parentheseOpen)
		|| !p.consume(tok::Type::identifier, &name))
			RETURN FALSE;

		Name := name.Content;
		p.consume(NULL);

		IF(!p.consume(tok::Type::parentheseClose))
		{
			DO(arg: Variable)
			{
				printf("parsing argument %d\n", <int>(Arguments.size()));
				IF(!arg.parse(p, FALSE, TRUE, FALSE))
					p.fail();
				Arguments.push_back(__cpp_std::move(arg));
			} WHILE(p.consume(tok::Type::comma))
			p.expect(tok::Type::parentheseClose);
		}

		IsInline := p.consume(tok::Type::inline);
		IsCoroutine := p.consume(tok::Type::at);

		Return := Type::parse(p);
		IF(!allow_body)
			IF(!Return.Ptr)
				p.fail();
			ELSE
			{
				p.expect(tok::Type::semicolon);
				RETURN TRUE;
			}

		// TODO: parse body statement.
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