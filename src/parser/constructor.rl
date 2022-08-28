INCLUDE "parser.rl"
INCLUDE "../ast/constructor.rl"
INCLUDE "stage.rl"

::rlc::parser parse_constructor(p: Parser&) ast::[Config]Constructor - std::Dyn
{
	t: Trace(&p, "constructor");

	symbol ::= symbol_constant::parse(p);

	position: src::Position;

	IF(symbol)
		position := p.expect(:braceOpen).Position;
	ELSE IF(tok ::= p.consume(:braceOpen))
		position := tok->Position;
	ELSE = NULL;

	out: ast::[Config]Constructor - std::Dyn;
	IF(!symbol && p.consume(:braceClose))
		out := :dup(<ast::[Config]DefaultConstructor>(BARE));
	ELSE IF(!symbol && p.consume_seq(:tripleDot, :braceClose))
		out := :dup(<ast::[Config]StructuralConstructor>(BARE));
	ELSE IF(!symbol && p.consume_seq(:null, :braceClose))
		out := :dup(<ast::[Config]NullConstructor>(BARE));
	ELSE IF(!symbol && p.consume_seq(:bare, :braceClose))
		out := :dup(<ast::[Config]BareConstructor>(BARE));
	ELSE
	{
		IF(!symbol && p.consume(:hash))
		{
			p.expect(:and);
			IF(name ::= p.consume(:identifier))
				out := :dup(<ast::[Config]CopyConstructor>(
					:named_arg(name->Content)));
			ELSE
				out := :dup(<ast::[Config]CopyConstructor>(:unnamed_arg));
		} ELSE IF(!symbol && p.consume(:doubleAnd))
		{
			IF(name ::= p.consume(:identifier))
				out := :dup(<ast::[Config]MoveConstructor>(
					:named_arg(name->Content)));
			ELSE
				out := :dup(<ast::[Config]MoveConstructor>(:unnamed_arg));
		} ELSE
		{
			_out ::= std::heap::[ast::[Config]CustomConstructor]new(BARE);
			out := :gc(_out);
			_out->Name := &&symbol;
			IF(!p.match(:braceClose))
				DO()
				{
					IF:!(arg ::= function::help::parse_arg(p))
						p.fail("expected argument");
					_out->Arguments += &&arg;
				} WHILE(p.consume(:comma))

		}
		p.expect(:braceClose);
	}

	out->Position := position;
	out->Inline := p.consume(:inline);

	IF(p.consume(:parentheseOpen))
	{
		alias ::= std::heap::[ast::[Config]Constructor::CtorAlias]new(BARE);
		out->Inits := :gc(alias);
		DO()
		{
			IF:!(exp ::= expression::parse(p))
				p.fail("expected expression");
			alias->Arguments += &&exp;
		} WHILE(p.consume(:comma))
		p.expect(:parentheseClose);
	} ELSE IF(p.consume(:colonEqual))
	{
		alias ::= std::heap::[ast::[Config]Constructor::CtorAlias]new(BARE);
		out->Inits := :gc(alias);
		IF:!(exp ::= expression::parse(p))
			p.fail("expected expression");
		alias->Arguments += &&exp;
	} ELSE
	{
		inits: ast::[Config]Constructor::ExplicitInits (BARE);
		dup_init ::= FALSE;
		IF(p.consume(:minusGreater))
		{
			dup_init := TRUE;
			DO(init: ast::[Config]Constructor::BaseInit (BARE))
			{
				p.expect(:parentheseOpen);
				IF(!p.consume(:parentheseClose))
				{
					DO()
					{
						IF(exp ::= expression::parse(p))
							init.Arguments += &&exp;
						ELSE p.fail("expected expression");
					} WHILE(p.consume(:comma))
					p.expect(:parentheseClose);
				}
				inits.BaseInits += &&init;
			} WHILE(p.consume(:comma))
		}

		IF(p.consume(:colon))
		{
			dup_init := TRUE;
			DO(init: ast::[Config]Constructor::MemberInit (BARE))
			{
				tok ::= p.expect(:identifier);
				(init.Member, init.Position) := (tok.Content, tok.Position);

				IF(p.consume(:colonEqual))
				{
					IF:!(exp ::= expression::parse(p))
						p.fail("expected expression");
					init.Arguments += &&exp;
				} ELSE
				{
					p.expect(:parentheseOpen);
					IF(!p.consume(:parentheseClose))
					{
						DO()
						{
							IF(exp ::= expression::parse(p))
								init.Arguments += &&exp;
							ELSE
								p.fail("expected expression");
						} WHILE(p.consume(:comma))
						p.expect(:parentheseClose);
					}
				}
				inits.MemberInits += &&init;
			} WHILE(p.consume(:comma))
		}

		IF(dup_init)
			out->Inits := :dup(&&inits);
	}

	IF(!p.consume(:semicolon))
	{
		locals: ast::LocalPosition;
		body: ast::[Config]BlockStatement (BARE);
		IF(!statement::parse_block(p, locals, body))
			p.fail("expected constructor body");
		out->Body := :dup(&&body);
	}

	= &&out;
}