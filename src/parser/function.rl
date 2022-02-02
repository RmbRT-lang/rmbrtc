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
	PRIVATE V: util::[Expression; Statement]DynUnion;

	{};
	{:gc, v: Expression \}: V(:gc(v));
	{:gc, v: Statement \}: V(:gc(v));

	# is_expression() INLINE BOOL := V.is_first();
	# expression() INLINE Expression \ := V.first();
	# is_statement() INLINE BOOL := V.is_second();
	# statement() INLINE Statement \ := V.second();

	# <BOOL> INLINE := V;

	[T:TYPE] THIS:=(v: T! &&) ExprOrStmt &
		:= std::help::custom_assign(THIS, <T!&&>(v));
}

(//
An anonymous function object that models a callable function.
/)
::rlc::parser Functoid VIRTUAL
{
	Arguments: std::[LocalVariable]Vector;
	Return: VariableType;
	Body: ExprOrStmt;
	IsInline: BOOL;
	IsCoroutine: BOOL;

	(//
	Parses a comma-separated list of arguments (without surrounding parentheses).
	Can be called multiple times to append new arguments.
	/)
	parse_args(
		p: Parser &,
		allow_multiple: BOOL,
		allow_empty: BOOL
	) VOID
	{
		readAny ::= FALSE;
		DO(arg: LocalVariable)
		{
			IF(!arg.parse_fn_arg(p))
			{
				IF(!readAny && !allow_empty)
					p.fail("expected argument");
				ELSE
					RETURN;
			}
			Arguments += &&arg;
		} WHILE(allow_multiple && p.consume(:comma))
	}

	/// Parses modifiers and return type.
	parse_rest_of_head(p: Parser &, returnType: BOOL) VOID
	{
		IsInline := p.consume(:inline);
		IsCoroutine := p.consume(:at);

		IF(!returnType)
			RETURN;

		IF(Return := :gc(parser::Type::parse(p)))
			RETURN;

		expectBody ::= p.consume(:questionMark);
		auto: parser::Type::Auto;
		auto.parse(p);
		Return := :gc(std::dup(&&auto));
	}

	parse_body(p: Parser &, allow_body: BOOL) VOID
	{
		IF(!allow_body)
		{
			IF(!Return)
				p.fail("expected explicit return type for bodyless function");
			p.expect(:semicolon);
			RETURN;
		}

		body: BlockStatement;
		IF(!Return)
		{
			expectBody ::= p.consume(:questionMark);
			auto: parser::Type::Auto;
			auto.parse(p);
			Return := :gc(std::dup(&&auto));

			IF(expectBody)
			{
				IF(!body.parse(p))
					p.fail("expected block statement");
				Body := :gc(std::dup(&&body));
			} ELSE
			{
				p.expect(:doubleColonEqual);
				Body := :gc(Expression::parse(p));
				p.expect(:semicolon);
			}
		} ELSE IF(!p.consume(:semicolon))
		{
			IF(body.parse(p))
				Body := :gc(std::dup(&&body));
			ELSE
			{
				p.expect(tok::Type::colonEqual);

				Body := :gc(Expression::parse(p));
				p.expect(:semicolon);
			}
		}
	}
}

(// A named functoid referrable to by name. /)
::rlc::parser Function VIRTUAL -> ScopeItem, Functoid
{
	Name: src::String;

	# FINAL name() src::String#& := Name;
	# FINAL overloadable() BOOL := FALSE;

	parse(
		p: Parser &,
		allow_body: BOOL,
		allow_operators: BOOL) BOOL
	{
		parOpen: tok::Type := :parentheseOpen;
		parClose: tok::Type := :parentheseClose;
		IF(!p.match_ahead(:parentheseOpen)
		|| !p.consume(:identifier, &Name))
		{
			RETURN FALSE;
		}

		t: Trace(&p, "function");

		p.expect(parOpen);
		Functoid::parse_args(p, TRUE, TRUE);
		p.expect(parClose);

		Functoid::parse_rest_of_head(p, TRUE);
		Functoid::parse_body(p, allow_body);

		RETURN TRUE;
	}
}

/// Global function.
::rlc::parser GlobalFunction -> Global, Function
{
	parse(p: Parser&) INLINE BOOL := Function::parse(p, TRUE, FALSE);
	parse_extern(p: Parser&) INLINE BOOL := Function::parse(p, FALSE, FALSE);
}

::rlc ENUM Abstractness
{
	none,
	virtual,
	abstract,
	override,
	final
}

::rlc::parser Abstractable VIRTUAL -> Member
{
	Abstractness: rlc::Abstractness;

	STATIC parse(p: Parser &) Abstractable *
	{
		ret: Abstractable * := NULL;

		abs ::= parse_abstractness(p);

		IF([Operator]parse_impl(p, abs, ret)
		|| [MemberFunction]parse_impl(p, abs, ret))
		{
			RETURN ret;
		}

		IF(abs != :none)
			p.fail("expected operator or function definition");

		RETURN NULL;
	}

	[T:TYPE] PRIVATE STATIC parse_impl(
		p: Parser &,
		abs: rlc::Abstractness,
		out: Abstractable *&) BOOL
	{
		v: T;
		v.Abstractness := abs;
		IF(v.parse(p))
		{
			out := std::dup(&&v);
			RETURN TRUE;
		}
		RETURN FALSE;
	}
}

::rlc::parser parse_abstractness(p: Parser &) Abstractness
{
	STATIC k_lookup: {tok::Type, rlc::Abstractness}#[](
		(:virtual, :virtual),
		(:abstract, :abstract),
		(:override, :override),
		(:final, :final));

	FOR(i ::= 0; i < ##k_lookup; i++)
		IF(p.consume(k_lookup[i].(0)))
			RETURN k_lookup[i].(1);
	RETURN :none;
}

(// Type conversion operator. /)
::rlc::parser Converter -> Member, Functoid
{
	Abstractness: rlc::Abstractness;

	# type() INLINE Type #\ := Functoid::Return.type();

	parse(p: Parser &) BOOL
	{
		IF(!p.consume(:less))
			RETURN FALSE;

		t: Trace(&p, "type converter");

		IF(!(Functoid::Return := :gc(Type::parse(p))))
			p.fail("expected type name");		

	}
}

::rlc::parser MemberFunction -> Abstractable, Function
{
	parse(p: Parser&) INLINE BOOL
		:= Function::parse(p, Abstractness != :abstract, TRUE);
}

/// Custom operator implementation.
::rlc::parser Operator -> Abstractable, Functoid
{
	Op: rlc::Operator;

	parse(p: Parser &) BOOL
	{
		postFix ::= p.consume(:this);
		IF(!postFix && !p.match_ahead(:this))
			RETURN FALSE;

		t: Trace(&p, "operator");

		singleArg ::= FALSE;
		allowArgs ::= TRUE;
		parOpen ::= tok::Type::parentheseOpen;
		parClose ::= tok::Type::parentheseClose;

		IF(postFix)
		{
			IF(detail::consume_overloadable_binary_operator(p, Op))
			{
				singleArg := TRUE;
			} ELSE IF(detail::consume_overloadable_postfix_operator(p, Op))
			{
				allowArgs := FALSE;
			} ELSE IF(p.match(:parentheseOpen))
			{
				Op := :call;
			} ELSE IF(p.match(:bracketOpen))
			{
				Op := :subscript;
				(parOpen, parClose) := (:bracketOpen, :bracketClose);
			} ELSE IF(p.match(:questionMark))
			{
				p.expect(:parentheseOpen);
				Functoid::parse_args(p, FALSE, FALSE);
				p.expect(:parentheseClose);
				p.expect(:colon);
				singleArg := TRUE;
			} ELSE
				p.fail("expected operator");
		} ELSE
		{
			IF(!detail::consume_overloadable_prefix_operator(p, Op))
				p.fail("expected overloadable prefix operator");
			p.expect(:this);
			allowArgs := FALSE;
		}

		IF(allowArgs)
		{
			p.expect(parOpen);
			Functoid::parse_args(p, !singleArg, !singleArg);
			p.expect(parClose);
		}

		Functoid::parse_rest_of_head(p, TRUE);
		Functoid::parse_body(p, Abstractness != :abstract);
	}
}

::rlc::parser Factory -> Member, Functoid
{
	parse(p: Parser &) BOOL
	{
		IF(!p.consume(:tripleLess))
			RETURN FALSE;

		t: Trace(&p, "factory");

		Functoid::parse_args(p, TRUE, FALSE);
		p.expect(:tripleGreater);
		Functoid::parse_rest_of_head(p, TRUE);
		Functoid::parse_body(p, TRUE);

		RETURN TRUE;
	}
}