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
		IF(!p.match_ahead(:parentheseOpen)
		|| !p.consume(:identifier, &Name))
			RETURN FALSE;

		t: Trace(&p, "function");
		p.expect(:parentheseOpen);

		IF(!p.consume(:parentheseClose))
		{
			DO(arg: LocalVariable)
			{
				IF(!arg.parse_fn_arg(p))
					p.fail("expected argument");
				Arguments += &&arg;
			} WHILE(p.consume(:comma))
			p.expect(:parentheseClose);
		}

		IsInline := p.consume(:inline);
		IsCoroutine := p.consume(:at);

		Return := :gc(Type::parse(p));
		IF(!allow_body)
			IF(!Return)
				p.fail("expected return type");
			ELSE
			{
				p.expect(:semicolon);
				RETURN TRUE;
			}

		body: BlockStatement;
		IF(body.parse(p))
		{
			Body := std::dup(&&body);
		} ELSE IF(!p.consume(:semicolon))
		{
			p.expect(Return.Ptr
				? tok::Type::colonEqual
				: tok::Type::doubleColonEqual);

			Body := Expression::parse(p);
			p.expect(:semicolon);
		}

		RETURN TRUE;
	}
}

::rlc::parser GlobalFunction -> Global, Function
{
	# FINAL type() Global::Type := :function;
	parse(p: Parser&) INLINE bool := Function::parse(p, TRUE);
	parse_extern(p: Parser&) INLINE bool := Function::parse(p, FALSE);
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

		IF(!Function::parse(p, TRUE))
		{
			IF(Abstractness != :none)
				p.fail("expected function");
			RETURN FALSE;
		}
		RETURN TRUE;
	}
}