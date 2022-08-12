INCLUDE "../ast/function.rl"
INCLUDE "stage.rl"
INCLUDE "statement.rl"

::rlc::parser::function parse_resolved_signature(
	p: Parser &,
	allow_multiple_args: BOOL,
	allow_no_args: BOOL,
	out: ast::[Config]ResolvedSig &
) VOID
{
	p.expect(:parentheseOpen);
	out.Arguments := help::parse_args(p, allow_multiple_args, allow_no_args);
	p.expect(:parentheseClose);
	out.IsCoroutine := p.consume(:at);
	IF!(out.Return := type::parse(p))
		p.fail("expected type");
}

::rlc::parser::function parse_signature(
	p: Parser &,
	allow_multiple_args: BOOL,
	allow_no_args: BOOL
) ast::[Config]FnSignature - std::Dyn
{
	p.expect(:parentheseOpen);
	arguments ::= help::parse_args(p, allow_multiple_args, allow_no_args);
	p.expect(:parentheseClose);
	= help::parse_signature_after_args(p, &&arguments);
}

::rlc::parser::function::help parse_signature_after_args(
	p: Parser &,
	arguments: ast::[Config]TypeOrArgument - std::DynVec&&
) ast::[Config]FnSignature - std::Dyn
{
	isCoroutine ::= p.consume(:at);
	IF(return ::= type::parse(p))
		= :gc(std::heap::[ast::[Config]ResolvedSig]new(
			&&arguments, isCoroutine, &&return));
	
	ret: ast::[Config]UnresolvedSig;
	ret.Arguments := &&arguments;
	ret.IsCoroutine := isCoroutine;
	p.expect(:questionMark);
	type::parse_auto(p, ret.Return);
	= :dup(&&ret);
}

(//
Parses a comma-separated list of arguments (without surrounding parentheses).
Can be called multiple times to append new arguments.
/)
::rlc::parser::function::help parse_args(
	p: Parser &,
	allow_multiple: BOOL,
	allow_empty: BOOL
) ast::[Config]TypeOrArgument-std::DynVec
{
	ret: ast::[Config]TypeOrArgument-std::DynVec;
	readAny ::= FALSE;
	DO()
		IF(arg ::= parse_arg(p))
			ret += &&arg;
		ELSE IF(!readAny && !allow_empty)
				p.fail("expected argument");
		ELSE BREAK;
		WHILE(allow_multiple && p.consume(:comma))

	= &&ret;
}

::rlc::parser::function::help parse_arg(
	p: Parser &
) ast::[Config]TypeOrArgument-std::Dyn
	:= variable::parse_fn_arg(p);

::rlc::parser::function::help parse_body(
	p: Parser &,
	allow_body: BOOL,
	out: ast::[Config]Functoid &) VOID
{
	locals: ast::LocalPosition;

	IF(!allow_body)
	{
		IF(<<ast::[Config]UnresolvedSig *>>(out.Signature!))
			p.fail("expected explicit return type for bodyless function");
		p.expect(:semicolon);
		RETURN;
	}

	IF(<<ast::[Config]ResolvedSig *>>(out.Signature!))
		IF(p.consume(:semicolon))
			RETURN;

	body: ast::[Config]BlockStatement;

	IF(p.consume(:colonEqual))
	{
		IF(!(out.Body := expression::parse(p)))
			p.fail("expected expression");
		p.expect(:semicolon);
	} ELSE
	{
		IF(!statement::parse_block(p, locals, body))
			p.fail("expected block statement");
		out.Body := :dup(&&body);
	}
}

::rlc::parser::function parse(
	p: Parser &,
	allow_body: BOOL,
	out: ast::[Config]Function &) BOOL
{
	nameTok: tok::Token-std::Opt;
	IF(!p.match_ahead(:parentheseOpen)
	|| !(nameTok := p.consume(:identifier)))
	{
		RETURN FALSE;
	}
	out.Name := nameTok!.Content;

	default: ast::[Config]DefaultVariant;

	t: Trace(&p, "function");

	default.Signature := parse_signature(p, TRUE, TRUE);
	default.IsInline := p.consume(:inline);
	help::parse_body(p, allow_body, default);

	out.Default := :dup(&&default);

	RETURN TRUE;
}

::rlc::parser::function parse_global(
	p: Parser &,
	out: ast::[Config]GlobalFunction &
) BOOL := parse(p, TRUE, out);

/// Parses an extern function (without the EXTERN keyword, use extern::parse()).
::rlc::parser::function::help parse_extern(
	p: Parser &,
	linkName: src::String - std::Opt
) ast::[Config]ExternFunction - std::Dyn
{
	nameTok: tok::Token-std::Opt;
	IF(!p.match_ahead(:parentheseOpen)) = NULL;
	IF:!(tok ::= p.consume(:identifier)) = NULL;

	t: Trace(&p, "function");

	name ::= tok->Content;
	signature: ast::[Config]ResolvedSig;
	parse_resolved_signature(p, TRUE, TRUE, signature);
	p.expect(:semicolon);

	= :a(&&name, &&signature, &&linkName);
}

::rlc::parser::abstractable parse(
	p: Parser &
) ast::[Config]Abstractable - std::Dyn
{
	ret: ast::[Config]Abstractable - std::Dyn;

	abs ::= parse_abstractness(p);

	IF(detail::parse_impl(p, abs, ret, parse_operator)
	|| detail::parse_impl(p, abs, ret, parse_member_function)
	|| detail::parse_impl(p, abs, ret, parse_converter))
	{
		= &&ret;
	}

	IF(abs != :none)
		p.fail("expected operator or function definition");

	= NULL;
}

::rlc::parser::abstractable::detail [T:TYPE] parse_impl(
	p: Parser &,
	abs: rlc::Abstractness,
	out: ast::[Config]Abstractable - std::Dyn &,
	parse_fn: ((Parser &, T!&) BOOL)) BOOL
{
	v: T := BARE;
	v.Abstractness := abs;
	IF(parse_fn(p, v))
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

::rlc::parser::abstractable parse_converter(
	p: Parser &,
	out: ast::[Config]Converter &
) BOOL
{
	IF:!(tok ::= p.consume(:less))
		= FALSE;
	out.Position := tok->Position;

	t: Trace(&p, "type converter");

	sig: ast::[Config]ResolvedSig;
	IF!(sig.Return := type::parse(p))
		p.fail("expected type name");
	p.expect(:greater);

	sig.IsCoroutine := p.consume(:at);
	out.Signature := :dup(&&sig);

	out.IsInline := p.consume(:inline);
	function::help::parse_body(p, out.Abstractness != :abstract, out);

	= TRUE;
}

::rlc::parser::abstractable parse_member_function(
	p: Parser&,
	out: ast::[Config]MemberFunction &
) BOOL INLINE
{
	= function::parse(p, out.Abstractness != :abstract, out);
}

::rlc::parser::abstractable parse_operator(p: Parser &, out: ast::[Config]Operator &) BOOL
{
	postFix ::= p.consume(:this);
	IF(!postFix && !p.match_ahead(:this))
		= FALSE;

	t: Trace(&p, "operator");

	singleArg ::= FALSE;
	allowArgs ::= TRUE;
	parOpen ::= tok::Type::parentheseOpen;
	parClose ::= tok::Type::parentheseClose;

	nothing: :nothing := :nothing;

	args: ast::[Config]TypeOrArgument - std::DynVec;

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
			args := function::help::parse_args(p, FALSE, FALSE);
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
		args := function::help::parse_args(p, !singleArg, !singleArg);
		p.expect(parClose);
	}

	out.Signature := function::help::parse_signature_after_args(p, &&args);
	out.IsInline := p.consume(:inline);
	function::help::parse_body(p, out.Abstractness != :abstract, out);
	= TRUE;
}

::rlc::parser::function parse_factory(
	p: Parser &,
	out: ast::[Config]Factory &
) BOOL
{
	IF:!(tok ::= p.consume(:tripleLess))
		= FALSE;

	out.Position := tok->Position;

	t: Trace(&p, "factory");

	args ::= function::help::parse_args(p, TRUE, FALSE);
	p.expect(:tripleGreater);

	out.Signature := help::parse_signature_after_args(p, &&args);
	out.IsInline := p.consume(:inline);
	help::parse_body(p, TRUE, out);

	= TRUE;
}