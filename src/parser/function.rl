INCLUDE "parser.rl"
INCLUDE "global.rl"
INCLUDE "member.rl"
INCLUDE "variable.rl"
INCLUDE "templatedecl.rl"
INCLUDE "statement.rl"

INCLUDE "../util/dynunion.rl"

INCLUDE 'std/help'

::rlc::parser ExprOrStmt
{
	PRIVATE V: util::[Expression, Statement]DynUnion;

	{};
	{v: Expression \}: V(v);
	{v: Statement \}: V(v);

	# is_expression() INLINE bool := V.is_first();
	# expression() INLINE Expression \ := V.first();
	# is_statement() INLINE bool := V.is_second();
	# statement() INLINE Statement \ := V.second();

	# <bool> INLINE := V;

	[T:TYPE] THIS:=(v: T! &&) ExprOrStmt &
		:= std::help::custom_assign(THIS, <T!&&>(v));
}

::rlc::parser Function -> VIRTUAL ScopeItem
{
	Arguments: std::[LocalVariable]Vector;
	Return: VariableType;
	Body: ExprOrStmt;
	IsInline: bool;
	IsCoroutine: bool;
	IsOperator: bool;
	Name: src::String;
	Operator: rlc::Operator;

	# FINAL name() src::String#& := Name;
	# FINAL overloadable() bool := TRUE;

	parse(
		p: Parser &,
		allow_body: bool,
		allow_operators: bool) bool
	{
		parOpen: tok::Type := :parentheseOpen;
		parClose: tok::Type := :parentheseClose;
		allowArgs ::= TRUE;
		singleArg ::= FALSE;

		IsOperator := FALSE;
		IF(!p.match_ahead(:parentheseOpen)
		|| !p.consume(:identifier, &Name))
		{
			IF(!allow_operators)
				RETURN FALSE;

			IF(p.consume(:this, &Name))
			{
				IF(detail::consume_overloadable_binary_operator(p, Operator))
				{
					singleArg := TRUE;
				} ELSE IF(detail::consume_overloadable_postfix_operator(p, Operator))
				{
					allowArgs := FALSE;
				} ELSE IF(p.match(:bracketOpen))
				{
					parOpen := :bracketOpen;
					parClose := :bracketClose;
				} ELSE IF(p.match(:questionMark))
				{
					p.expect(:parentheseOpen);
					arg: LocalVariable;
					IF(!arg.parse_fn_arg(p))
						p.fail("expected argument");
					Arguments += &&arg;
					p.expect(:parentheseClose);
					p.expect(:colon);
					singleArg := TRUE;
				} ELSE
					p.fail("expected operator");
				IsOperator := TRUE;
			} ELSE IF(p.match_ahead(:this))
			{
				IsOperator := TRUE;
				IF(!detail::consume_overloadable_prefix_operator(p, Operator))
					p.fail("expected overloadable prefix operator");
				p.expect(:this);
				allowArgs := FALSE;
			} ELSE IF(p.consume(:less))
			{
				allowArgs := FALSE;
				IF(!(Return := Type::parse(p)))
					p.fail("expected type");
				p.expect(:greater);
			} ELSE
				RETURN FALSE;
		}

		t: Trace(&p, "function");

		IF(!Return && allowArgs)
		{
			p.expect(parOpen);

			IF(singleArg || !p.consume(parClose))
			{
				DO(arg: LocalVariable)
				{
					IF(!arg.parse_fn_arg(p))
						p.fail("expected argument");
					Arguments += &&arg;
				} WHILE(!singleArg && p.consume(:comma))
				p.expect(parClose);
			}
		}

		IsInline := p.consume(:inline);
		IsCoroutine := p.consume(:at);

		IF(!Return)
			Return := Type::parse(p);

		IF(!allow_body)
			IF(!Return)
				p.fail("expected return type");
			ELSE
			{
				p.expect(:semicolon);
				RETURN TRUE;
			}

		body: BlockStatement;
		IF(!Return)
		{
			expectBody ::= p.consume(:questionMark);
			auto: Type::Auto;
			auto.parse(p);
			Return := std::dup(&&auto);

			IF(expectBody)
			{
				IF(!body.parse(p))
					p.fail("expected block statement");
				Body := std::dup(&&body);
			} ELSE
			{
				p.expect(:doubleColonEqual);
				Body := Expression::parse(p);
				p.expect(:semicolon);
			}
		} ELSE IF(!p.consume(:semicolon))
		{
			IF(body.parse(p))
				Body := std::dup(&&body);
			ELSE
			{
				p.expect(tok::Type::colonEqual);

				Body := Expression::parse(p);
				p.expect(:semicolon);
			}
		}

		RETURN TRUE;
	}
}

::rlc::parser GlobalFunction -> Global, Function
{
	# FINAL type() Global::Type := :function;
	parse(p: Parser&) INLINE bool := Function::parse(p, TRUE, FALSE);
	parse_extern(p: Parser&) INLINE bool := Function::parse(p, FALSE, FALSE);
}

::rlc ENUM Abstractness
{
	none,
	virtual,
	abstract,
	override,
	final
}

::rlc::parser MemberFunction -> Member, Function
{
	Abstractness: rlc::Abstractness;

	# FINAL type() Member::Type := :function;

	parse(p: Parser&) INLINE bool
	{
		STATIC k_lookup: {tok::Type, rlc::Abstractness}#[](
			(:virtual, :virtual),
			(:abstract, :abstract),
			(:override, :override),
			(:final, :final));

		Abstractness := :none;
		FOR(i ::= 0; i < ::size(k_lookup); i++)
			IF(p.consume(k_lookup[i].(0)))
			{
				Abstractness := k_lookup[i].(1);
				BREAK;
			}

		IF(!Function::parse(p, Abstractness != :abstract, TRUE))
		{
			IF(Abstractness != :none)
				p.fail("expected function");
			RETURN FALSE;
		}
		RETURN TRUE;
	}
}