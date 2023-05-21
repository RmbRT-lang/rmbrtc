INCLUDE "parser.rl"
INCLUDE "../ast/constructor.rl"
INCLUDE "stage.rl"

::rlc::parser parse_constructor(p: Parser&) ast::[Config]Constructor - std::ValOpt
{
	t: Trace(&p, "constructor");

	symbol ::= symbol_constant::parse(p);

	position: src::Position (BARE);

	IF(symbol)
		position := p.expect(:braceOpen).Position;
	ELSE IF(tok ::= p.consume(:braceOpen))
		position := tok->Position;
	ELSE = NULL;

	out: ast::[Config]Constructor - std::Val (BARE);
	IF(!symbol && p.consume(:braceClose))
		out := :a.ast::[Config]DefaultConstructor(BARE);
	ELSE IF(!symbol && p.consume_seq(:tripleDot, :braceClose))
		out := :a.ast::[Config]StructuralConstructor(BARE);
	ELSE IF(!symbol && p.consume_seq(:null, :braceClose))
		out := :a.ast::[Config]NullConstructor(BARE);
	ELSE IF(!symbol && p.consume_seq(:bare, :braceClose))
		out := :a.ast::[Config]BareConstructor(BARE);
	ELSE
	{
		IF(!symbol && p.consume(:hash))
		{
			p.expect(:amp);
			IF(name ::= p.consume(:identifier))
				out := :a.ast::[Config]CopyConstructor(
					:named_arg(name->Content, name->Position));
			ELSE
				out := :a.ast::[Config]CopyConstructor(:unnamed_arg);
		} ELSE IF(!symbol && p.consume(:doubleAmp))
		{
			IF(name ::= p.consume(:identifier))
				out := :a.ast::[Config]MoveConstructor(
					:named_arg(name->Content, name->Position));
			ELSE
				out := :a.ast::[Config]MoveConstructor(:unnamed_arg);
		} ELSE
		{
			_out ::= std::heap::[ast::[Config]CustomConstructor]new(BARE);
			out := :gc(_out);
			_out->Name := &&symbol;
			IF(!p.match(:braceClose))
				DO()
					_out->Args += function::help::parse_arg_x(p);
					WHILE(p.consume(:comma))
		}
		p.expect(:braceClose);
	}

	out.mut_ok().Position := position;
	out.mut_ok().Inline := p.consume(:inline);

	IF(p.consume(:parentheseOpen))
	{
		alias ::= std::heap::[ast::[Config]Constructor::CtorAlias]new(BARE);
		out.mut_ok().Inits := :gc(alias);
		IF(!p.match(:parentheseClose))
			DO()
				alias->Arguments += expression::parse_x(p);
				WHILE(p.consume(:comma))
		p.expect(:parentheseClose);
	} ELSE IF(p.consume(:colonEqual))
	{
		alias ::= std::heap::[ast::[Config]Constructor::CtorAlias]new(BARE);
		out.mut_ok().Inits := :gc(alias);
		alias->Arguments += expression::parse_x(p);
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
						init.Arguments += expression::parse_x(p);
						WHILE(p.consume(:comma))
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
					IF(!p.consume(:noinit))
						init.Arguments := :a(:vec(expression::parse_x(p)));
				} ELSE
				{
					p.expect(:parentheseOpen);
					IF(p.consume(:noinit))
						p.expect(:parentheseClose);
					ELSE
					{
						init.Arguments := :a();
						IF(!p.consume(:parentheseClose))
						{
							DO()
								*init.Arguments += expression::parse_x(p);
								WHILE(p.consume(:comma))
							p.expect(:parentheseClose);
						}
					}
				}
				inits.MemberInits += &&init;
			} WHILE(p.consume(:comma))
		}

		IF(dup_init)
			out.mut_ok().Inits := :dup(&&inits);
	}

	IF(!p.consume(:semicolon))
	{
		body: ast::[Config]BlockStatement (BARE);
		IF(!statement::parse_block(p, body))
			p.fail("expected constructor body");
		out.mut_ok().Body := :dup(&&body);
	}

	= &&out;
}