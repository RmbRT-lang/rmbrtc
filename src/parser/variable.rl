INCLUDE "../ast/variable.rl"
INCLUDE "../ast/type.rl"
INCLUDE "expression.rl"
INCLUDE "type.rl"
INCLUDE "stage.rl"

::rlc::parser::variable
{
	parse_global(p: Parser&) ast::[Config]GlobalVariable - std::Dyn
	{
		_: Trace(p, "global variable");

		nt ::= help::parse_initialised_name_and_type(p);
		IF(!nt) = NULL;

		inits: ast::[Config]Expression - std::DynVec;

		IF(<<ast::type::[Config]Auto *>>(nt->Type!))
			inits += help::parse_auto_init(p);
		ELSE
			inits := help::parse_initialisers(p);

		p.expect(:semicolon);

		= :new(nt->Name, &&nt->Type, &&inits);
	}

	parse_extern(p: Parser&) ast::[Config]GlobalVariable - std::Dyn
	{
		_: Trace(p, "extern variable");

		nt ::= help::parse_uninitialised_name_and_type(p);
		IF(!nt) = NULL;
		p.expect(:semicolon);
		= :new(&&nt->(0).Content, &&nt->(1));
	}

	parse_member(
		p: Parser&,
		out: ast::[Config]MemberVariable &,
		static: BOOL
	) ast::[Config]MaybeAnonMemberVar - std::Dyn
	{
		_: Trace(p, "member variable");

		ret: ast::[Stage]MaybeAnonMemberVar - std::Dyn;

		IF(static)
		{
			IF(nt ::= help::parse_initialised_name_and_type(p))
			{
				inits: ast::[Config]Expression - std::DynVec;

				IF(<<ast::type::[Config]Auto *>>(nt->Type!))
					inits += help::parse_auto_init(p);
				ELSE
					inits := help::parse_initialisers(p);

				p.expect(:semicolon);

				= :gc(std::heap::[ast::[Config]StaticMemberVariable]new(
					&&nt->(0).Content, &&nt->(1), &&inits));
			} ELSE = NULL;
		}
		ELSE
		{
			help::parse_variable_opt_name_and_type(p);
			IF(nt ::= help::parse_uninitialised_name_and_type(p))
			{
				p.expect(:semicolon);
				= :gc(std::heap::[ast::[Config]MemberVariable]new(
					&&nt->(0).Content, &&nt->(1)));
			} ELSE IF(is_optionally_named_variable_start(p))
			{	// Anonymous member variable.
				t ::= type::parse(p);
				IF(!t) p.fail("expected type");
				p.expect(:semicolon);
				= :gc(std::heap::[ast::[Config]AnonMemberVariable]new(t));
			}
		}
		= TRUE;
	}

	parse_catch(
		p: Parser &
	) ast::[Config]TypeOrCatchVariable - std::Dyn
	{
		_: Trace(p, "catch variable");

		IF(nt ::= help::parse_uninitialised_name_and_type(p))
		{
			p.expect(:semicolon);
			= :gc(std::heap::[ast::[Config]MemberVariable]new(
				&&nt->(0).Content, &&nt->(1)));
		} ELSE IF(is_optionally_named_variable_start(p))
		{	// Anonymous member variable.
			t ::= type::parse(p);
			IF(!t) p.fail("expected type");
			p.expect(:semicolon);
			= :gc(std::heap::[ast::[Config]AnonMemberVariable]new(t));
		}
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
		start ::= help::parse_variable_opt_name_and_type(p);
		IF(!start)
			= NULL;

		IF(start.Name)
			= :gc(std::heap::[Argument]new(start.Name->Content, &&start.Type));
		ELSE
			= &&start.Type;
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


	::help NameAndInitType
	{
		Name: tok::Token;
		Type: ast::[Config]MaybeAutoType;
	}
	::help parse_initialised_name_and_type(p: Parser) NameAndInitType - std::Opt
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

	::help OptNameAndType
	{
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
			t ::= type::parse(p);
			IF(!t) p.fail("expected type");
			= :a(:a(name), &&t);
		}

		IF(t ::= type::parse(p))
			= :a(NULL, &&t);
		= NULL;
	}

	::help parse_auto_init(p: Parser &) ast::[Config]Expression-std::Dyn
	{
		p.expect(:doubleColonEqual);
		init ::= expression::parse(p);
		IF(!init) p.fail("expected expression");
		= &&init;
	}

	::help parse_initialisers(p: Parser &) ast::[Config]Expression - std::DynVec
	{
		inits: ast::[Config]Expression - std::DynVec;
		IF(p.consume(:colonEqual))
		{
			init ::= expression::parse(p);
			IF(!init) p.fail("expected expression");
			inits += &&init;
		} ELSE IF(p.consume(:parentheseOpen))
		{
			IF(!p.consume(:parentheseClose))
			{
				DO()
				{
					init ::= expression::parse(p);
					IF(!init) p.fail("expected expression");
					inits += &&init;
				} WHILE(!p.consume(:comma))
				p.expect(:parentheseClose);
			}
		}

		= &&inits;
	}
}