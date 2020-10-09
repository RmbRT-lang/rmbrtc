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

	CONSTRUCTOR();
	CONSTRUCTOR(v: Expression \): V(v);
	CONSTRUCTOR(v: Statement \): V(v);

	# is_expression() INLINE bool := V.is_first();
	# expression() INLINE Expression \ := V.first();
	# is_statement() INLINE bool := V.is_second();
	# statement() INLINE Statement \ := V.second();

	# CONVERT(bool) INLINE NOTYPE! := V;

	[T:TYPE] ASSIGN(v: T! &&) ExprOrStmt &
		:= std::help::custom_assign(*THIS, __cpp_std::[T!]forward(v));
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
			IF(!Return)
				p.fail("expected return type");
			ELSE
			{
				p.expect(tok::Type::semicolon);
				RETURN TRUE;
			}

		body: BlockStatement;
		IF(body.parse(p))
		{
			Body := std::dup(__cpp_std::move(body));
		} ELSE IF(!p.consume(tok::Type::semicolon))
		{
			p.expect(Return.Ptr
				? tok::Type::colonEqual
				: tok::Type::doubleColonEqual);

			Body := Expression::parse(p);
			p.expect(tok::Type::semicolon);
		}

		RETURN TRUE;
	}
}

::rlc::parser GlobalFunction -> Global, Function
{
	# FINAL type() Global::Type := Global::Type::function;
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

	# FINAL type() Member::Type := Member::Type::function;

	parse(p: Parser&) INLINE bool
	{
		STATIC k_lookup: std::[tok::Type, rlc::Abstractness]Pair#[](
			std::pair(tok::Type::virtual, rlc::Abstractness::virtual),
			std::pair(tok::Type::abstract, rlc::Abstractness::abstract),
			std::pair(tok::Type::override, rlc::Abstractness::override),
			std::pair(tok::Type::final, rlc::Abstractness::final));

		Abstractness := rlc::Abstractness::none;
		FOR(i ::= 0; i < ::size(k_lookup); i++)
			IF(p.consume(k_lookup[i].First))
			{
				Abstractness := k_lookup[i].Second;
				BREAK;
			}

		IF(!Function::parse(p, TRUE))
		{
			IF(Abstractness != rlc::Abstractness::none)
				p.fail("expected function");
			RETURN FALSE;
		}
		RETURN TRUE;
	}
}