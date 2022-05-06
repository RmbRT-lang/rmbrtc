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
	IF(p.consume(:braceClose))
		out := :gc(std::heap::[ast::[Config]DefaultConstructor]new());
	ELSE
	{
		IF(!symbol && p.consume(:hash))
		{
			p.expect(:and);
			IF(name ::= p.consume(:identifier))
				out := :gc(std::heap::[ast::[Config]CopyConstructor]new(
					:named_arg(name->Content)));
			ELSE
				out := :gc(std::heap::[ast::[Config]CopyConstructor]new(:unnamed_arg));
		} ELSE IF(!symbol && p.consume(:doubleAnd))
		{
			IF(name ::= p.consume(:identifier))
				out := :gc(std::heap::[ast::[Config]MoveConstructor]new(
					:named_arg(name->Content)));
			ELSE
				out := :gc(std::heap::[ast::[Config]MoveConstructor]new(:unnamed_arg));
		} ELSE
		{
			_out ::= std::heap::[ast::[Config]CustomConstructor]new();
			out := :gc(_out);
			_out->Name := &&symbol;
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
		alias ::= std::heap::[ast::[Config]Constructor::CtorAlias]new();
		out->Inits := :gc(alias);
		DO()
		{
			IF(exp ::= expression::parse(p))
				alias->Arguments += &&exp;
			ELSE p.fail("expected expression");
		} WHILE(p.consume(:comma))
		p.expect(:parentheseClose);
	} ELSE
	{
		inits: ast::[Config]Constructor::ExplicitInits;
		dup_init ::= FALSE;
		IF(p.consume(:minusGreater))
		{
			dup_init := TRUE;
			DO(init: ast::[Config]Constructor::BaseInit)
			{
				IF(!symbol::parse(p, init.Base))
					p.fail("expected base class name");
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
			DO(init: ast::[Config]Constructor::MemberInit)
			{
				tok ::= p.expect(:identifier);
				(init.Member, init.Position) := (tok.Content, tok.Position);

				p.expect(:parentheseOpen);
				IF(!p.consume(:parentheseClose))
				{
					DO()
					{
						IF(exp ::= expression::parse(p))
							init.Arguments += :gc(exp);
						ELSE
							p.fail("expected expression");
					} WHILE(p.consume(:comma))
					p.expect(:parentheseClose);
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
		body: ast::[Config]BlockStatement;
		IF(!statement::parse_block(p, locals, body))
			p.fail("expected constructor body");
		out->Body := :dup(&&body);
	}

	= &&out;
}