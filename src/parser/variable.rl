INCLUDE "../ast/variable.rl"
INCLUDE "../ast/type.rl"
INCLUDE "expression.rl"
INCLUDE "type.rl"
INCLUDE "stage.rl"

::rlc::parser::variable
{
	parse_global(p: Parser&, out: ast::[Config]GlobalVariable&) BOOL
	{
		IF(!parse_var_decl(p, out))
			= FALSE;
		p.expect(:semicolon);
		= TRUE;
	}

	parse_extern(p: Parser&, out: ast::[Config]GlobalVariable &) BOOL
	{
		IF(!parse(p, out, TRUE, FALSE, FALSE))
			= FALSE;
		p.expect(:semicolon);
		= TRUE;
	}

	parse_member(
		p: Parser&,
		out: ast::[Config]MemberVariable &,
		static: BOOL
	) BOOL
	{
		IF(static)
		{
			IF(!parse_var_decl(p))
				= FALSE;
		}
		ELSE
		{
			IF(!parse_fn_arg(p))
				= FALSE;
		}
		p.expect(:semicolon);
		= TRUE;
	}

	parse_catch(
		p: Parser &
	) ast::[Config]TypeOrCatchVariable - std::Dyn
	{
		IF(parse_variable_opt_name_and_type(p, FALSE))
		IF(!start)
			= NULL;

		name: tok::Token - std::Opt;
		type: ast::[Config]Type - std::Dyn;
		(name, type) := &&*start;

		IF(name)
			= std::heap::[CatchVariable]new(name->Content, &&type);
		ELSE
			= &&type;
	}

	parse_local(
		p: Parser &,
		expect_semicolon: BOOL
	) ast::[Config]LocalVariable - std::Dyn
	{
		name: tok::Token;
		type: ast::[Config]Type - std::Dyn;

		IF(start ::= help::parse_variable_name_and_type(p, TRUE))
			(name, type) := &&*start;
		ELSE
			= NULL;

		_: Trace(p, "local variable");


		TYPE SWITCH(type!)
		{
		DEFAULT: {}
		}
		

		IF(expect_semicolon)
			p.expect(:semicolon);

		= TRUE;
	}

	parse_fn_arg(
		p: Parser&,
		out: ast::[Config]Variable &
	) [Stage]TypeOrArgument-std::Dyn
	{
		IF(parse_variable_opt_name_and_type(p, FALSE))
		IF(!start)
			= NULL;

		name: tok::Token - std::Opt;
		type: ast::[Config]Type - std::Dyn;
		(name, type) := &&*start;

		IF(name)
			= std::heap::[Argument]new(name->Content, &&type);
		ELSE
			= &&type;
	}

	::help needed_without_name: tok::Type#[](
			:bracketOpen, :braceOpen,
			:doubleColon, :colon,
			:void, :bool, :char, :int, :uint, :sm, :um, :null);

	// (token, onlyIfNeedsName)
	::help needed_after_name: {tok::Type, BOOL}#[](
			(:colon, TRUE),
			(:colonEqual, TRUE),
			(:doubleColonEqual, TRUE),
			(:hash, TRUE),
			(:dollar, TRUE),
			(:exclamationMark, FALSE),
			(:and, FALSE),
			(:doubleAnd, FALSE),
			(:asterisk, FALSE),
			(:backslash, FALSE),
			(:at, FALSE),
			(:doubleAt, FALSE),
			(:doubleDotExclamationMark, FALSE),
			(:doubleDotQuestionMark, FALSE),
			(:doubleColon, FALSE),
			(:minus, FALSE),
			(:semicolon, FALSE),
			(:comma, FALSE),
			(:parentheseClose, FALSE),
			(:braceClose, FALSE));

	::help is_named_variable_start(p: Parser &, needs_name: BOOL) BOOL
	{
		IF(!p.match(:identifier))
			= FALSE;
		FOR(i ::= 0; i < ##help::needed_after_name; i++)
			IF((!needs_name || help::needed_after_name[i].(1))
			&& p.match_ahead(help::needed_after_name[i].(0)))
				= TRUE;
		= FALSE;
	}

	::help is_optionally_named_variable_start(p: Parser &) BOOL
	{
		IF(is_named_variable_start(p, FALSE))
			= TRUE;
		FOR(i ::= 0; i < ##k_needed_without_name; i++)
			IF(p.match(help::needed_without_name[i]))
				= TRUE;
		= FALSE;
	}

	/// A named uninitialised variable.
	::help parse_uninitialised_name_and_type(
		p: Parser &
	) {
		tok::Token,
		ast::[Config]Type - std::Dyn
	} - std::Opt
	{
		IF(!is_named_variable_start(p, TRUE))
			= NULL;

		name ::= p.consume(:identifier)!;
		p.expect(:colon);
		t ::= type::parse(p);
		IF(!t)
			p.fail("experted type");
		= :a(:a(name), &&p);
	}

	::help parse_initialised_name_and_type(p: Parser) {
		tok::Token,
		ast::[Config]MaybeAutoType
	} - std::Opt
	{
		IF(!is_named_variable_start(p, TRUE))
			= NULL;

		name ::= p.expect(:identifier);

		// "name: type" style variable?
		IF(p.consume(:colon))
		{
			has_name := TRUE;

			IF(p.consume(:questionMark))
			{
				auto: type::[Config]Auto;
				parse_auto(p, auto);
				= :a(:a(name), :dup(&&auto));
			}
			= :a(:a(name), type::parse(p));
		} ELSE IF(allow_initialiser)
		{
			STATIC k_need_ahead: tok::Type#[](
				:hash,
				:dollar,
				:doubleColonEqual);

			FOR(i ::= 0; i < ##k_need_ahead; i++)
			{
				IF(p.match(k_need_ahead[i]))
				{
					auto: Auto;
					parse_auto_no_ref(p, auto);
					p.expect(:doubleColonEqual);
					= :a(:a(name), :dup(&&auto));
				}
			}
			DIE;
		}

		DIE;
	}

	::help OptNameAndType {
		Name: tok::Token - std::Opt;
		Type: ast::[Config]Type - std::Dyn;
	}

	::help parse_variable_opt_name_and_type(
		p: Parser &
	) OptNameAndType - std::Opt
	{
		IF(p.match_seq(:identifier, :colon))
		{
			name ::= p.consume(:identifier)!;
			p.eat_token()!;

			IF(p.consume(:questionMark))
			{
				auto: type::[Config]Auto;
				parse_auto(p, auto);
				p.expect(:colonEqual);
				= :a(:a(name), :dup(&&auto));
			} ELSE
				= :a(:a(name), type::parse(p));
		}

		IF(t ::= type::parse(p))
			= :a(NULL, &&t);
		= NULL;
	}

	parse(
		p: Parser&,
		out: ast::[Config]Variable &,
		needs_name: BOOL,
		allow_initialiser: BOOL,
		force_initialiser: BOOL) BOOL
	{
		...;

		IF(!has_name && needs_name)
			= FALSE;

		IF(!needs_type)
		{
			IF(init ::= expression::parse(p))
				out.InitValues += &&init;
			ELSE
				p.fail("expected expression");
		} ELSE
		{
			IF(!(out.Type := type::parse(p)))
			{
				IF(needs_name)
					p.fail("expected name");
				ELSE
					= FALSE;
			}

			IF(allow_initialiser)
			{
				isParenthese ::= 0;
				IF(p.consume(:colonEqual)
				|| (isParenthese := p.consume(:parentheseOpen)))
				{
					// check for empty initialiser.
					IF(!isParenthese
					|| !p.consume(:parentheseClose))
					{
						DO()
						{
							IF(arg ::= expression::parse(p))
								out.InitValues += &&arg;
							ELSE
								p.fail("expected expression");
						} WHILE(isParenthese && p.consume(:comma))

						IF(isParenthese)
							p.expect(:parentheseClose);
					}
				} ELSE IF(force_initialiser)
				{
					p.fail("expected ':=' or '('");
				}
			}
		}

		= TRUE;
	}
}