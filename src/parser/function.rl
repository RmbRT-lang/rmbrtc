INCLUDE "../ast/function.rl"
INCLUDE "stage.rl"
INCLUDE "statement.rl"

(//
Parses a comma-separated list of arguments (without surrounding parentheses).
Can be called multiple times to append new arguments.
/)
::rlc::parser::function parse_args(
	p: Parser &,
	out: ast::[Config]Functoid &,
	allow_multiple: BOOL,
	allow_empty: BOOL
) VOID
{
	readAny ::= FALSE;
	DO(arg: ast::[Config]LocalVariable-std::Dyn)
	{
		IF(!(arg := parse_arg(p)))
		{
			IF(!readAny && !allow_empty)
				p.fail("expected argument");
			ELSE
				RETURN;
		}
		out.Arguments += &&arg;
	} WHILE(allow_multiple && p.consume(:comma))
}

::rlc::parser::function parse_arg(
	p: Parser &
) ast::[Config]TypeOrArgument-std::Dyn
	:= variable::parse_fn_arg(p);


/// Parses modifiers and return type.
::rlc::parser::function parse_rest_of_head(
	p: Parser &,
	out: ast::[Config]Functoid &,
	returnType: BOOL) VOID
{
	out.IsInline := p.consume(:inline);
	out.IsCoroutine := p.consume(:at);

	IF(!returnType)
		RETURN;

	IF(out.Return := parser::type::parse(p))
		RETURN;

	expectBody ::= p.consume(:questionMark);
	auto: ast::type::[Config]Auto;
	type::parse_auto(p, auto);
	out.Return := :dup(&&auto);
}

::rlc::parser::function parse_body(
	p: Parser &,
	allow_body: BOOL,
	out: ast::[Config]Functoid &) VOID
{
	locals: ast::LocalPosition;

	IF(!allow_body)
	{
		IF(!out.Return)
			p.fail("expected explicit return type for bodyless function");
		p.expect(:semicolon);
		RETURN;
	}

	body: ast::[Config]BlockStatement;
	IF(!out.Return)
	{
		expectBody ::= p.consume(:questionMark);
		auto: ast::type::[Config]Auto;
		type::parse_auto(p, auto);
		out.Return := :dup(&&auto);

		IF(expectBody)
		{
			IF(!statement::parse_block(p, locals, body))
				p.fail("expected block statement");
			out.Body := :dup(&&body);
		} ELSE
		{
			p.expect(:doubleColonEqual);
			IF(!(out.Body := expression::parse(p)))
				p.fail("expected expression");
			p.expect(:semicolon);
		}
	} ELSE IF(!p.consume(:semicolon))
	{
		IF(statement::parse_block(p, locals, body))
			out.Body := :dup(&&body);
		ELSE
		{
			p.expect(:colonEqual);

			IF(!(out.Body := expression::parse(p)))
				p.fail("expected expression");
			p.expect(:semicolon);
		}
	}
}


::rlc::parser::function parse(
	p: Parser &,
	allow_body: BOOL,
	allow_operators: BOOL,
	out: ast::[Config]Function &) BOOL
{
	parOpen: tok::Type := :parentheseOpen;
	parClose: tok::Type := :parentheseClose;
	nameTok: tok::Token-std::Opt;
	IF(!p.match_ahead(:parentheseOpen)
	|| !(nameTok := p.consume(:identifier)))
	{
		RETURN FALSE;
	}
	out.Name := nameTok!.Content;

	default: ast::[Config]DefaultVariant;

	t: Trace(&p, "function");

	p.expect(parOpen);
	parse_args(p, default, TRUE, TRUE);
	p.expect(parClose);

	parse_rest_of_head(p, default, TRUE);
	parse_body(p, allow_body, default);

	out.Default := :dup(&&default);

	RETURN TRUE;
}

::rlc::parser::abstractable parse(p: Parser &) ast::[Config]Abstractable *
{
	ret: ast::[Config]Abstractable *;

	abs ::= parse_abstractness(p);

	IF(detail::[ast::[Config]Operator]parse_impl(p, abs, ret)
	|| detail::[ast::[Config]MemberFunction]parse_impl(p, abs, ret))
	{
		RETURN ret;
	}

	IF(abs != :none)
		p.fail("expected operator or function definition");

	RETURN NULL;
}

::rlc::parser::abstractable::detail [T:TYPE] parse_impl(
	p: Parser &,
	abs: rlc::Abstractness,
	out: ast::[Config]Abstractable *&) BOOL
{
	v: T;
	v.Abstractness := abs;
	IF(v.parse(p))
	{
		out := :dup(&&v);
		RETURN TRUE;
	}
	RETURN FALSE;
}

::rlc::parser::abstractable parse_abstractness(p: Parser &) Abstractness
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

::rlc::parser::abstractable parse_converter(p: Parser &, out: ast::[Config]Converter &) BOOL
{
	IF(tok ::= p.consume(:less))
		out.Position := tok->Position;
	ELSE = FALSE;

	t: Trace(&p, "type converter");

	IF(!(out.Return := type::parse(p)))
		p.fail("expected type name");

	p.expect(:greater);

	function::parse_rest_of_head(p, out, FALSE);
	function::parse_body(p, out.Abstractness != :abstract, out);

	RETURN TRUE;
}

::rlc::parser::abstractable parse_member_function(
	p: Parser&,
	out: ast::[Config]MemberFunction &
) INLINE BOOL := function::parse(p, out.Abstractness != :abstract, TRUE, out);

::rlc::parser::abstractable parse_operator(p: Parser &, out: ast::[Config]Operator &) BOOL
{
	postFix ::= p.consume(:this);
	IF(!postFix && !p.match_ahead(:this))
		RETURN FALSE;

	t: Trace(&p, "operator");

	singleArg ::= FALSE;
	allowArgs ::= TRUE;
	parOpen ::= tok::Type::parentheseOpen;
	parClose ::= tok::Type::parentheseClose;

	nothing: :nothing := :nothing;

	IF(postFix)
	{
		IF(expression::consume_overloadable_binary_operator(p, out.Op))
		{
			singleArg := TRUE;
		} ELSE IF(expression::consume_overloadable_postfix_operator(p, out.Op))
		{
			allowArgs := FALSE;
		} ELSE IF(p.match(:parentheseOpen))
		{
			out.Op := :call;
		} ELSE IF(p.match(:bracketOpen))
		{
			out.Op := :subscript;
			(parOpen, parClose) := (:bracketOpen, :bracketClose);
		} ELSE IF(p.match(:questionMark))
		{
			p.expect(:parentheseOpen);
			function::parse_args(p, out, FALSE, FALSE);
			p.expect(:parentheseClose);
			p.expect(:colon);
			singleArg := TRUE;
		} ELSE
			p.fail("expected operator");
	} ELSE
	{
		IF(!expression::consume_overloadable_prefix_operator(p, out.Op))
			p.fail("expected overloadable prefix operator");
		p.expect(:this);
		allowArgs := FALSE;
	}

	IF(allowArgs)
	{
		p.expect(parOpen);
		function::parse_args(p, out, !singleArg, !singleArg);
		p.expect(parClose);
	}

	function::parse_rest_of_head(p, out, TRUE);
	function::parse_body(p, out.Abstractness != :abstract, out);
}

::rlc::parser::function parse_factory(p: Parser &, out: ast::[Config]Factory &) BOOL
{
	IF(tok ::= p.consume(:tripleLess))
		out.Position := tok->Position;
	ELSE = FALSE;

	t: Trace(&p, "factory");

	function::parse_args(p, out, TRUE, FALSE);
	p.expect(:tripleGreater);
	function::parse_rest_of_head(p, out, TRUE);
	function::parse_body(p, TRUE, out);

	RETURN TRUE;
}