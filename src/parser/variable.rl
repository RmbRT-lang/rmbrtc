INCLUDE "../ast/variable.rl"
INCLUDE "../ast/type.rl"
INCLUDE "expression.rl"
INCLUDE "type.rl"
INCLUDE "stage.rl"

::rlc::parser::variable
{
	parse_global(p: Parser&) ast::[Config]GlobalVariable - std::ValOpt
	{
		t: Trace(&p, "global variable");
		IF:!(nt ::= help::parse_initialised_name_and_type(p))
			= NULL;

		inits: ast::[Config]Expression - std::ValVec - std::Opt;

		IF(<<ast::type::[Config]Auto #*>>(nt->Type))
			inits := :a(:vec(
				help::parse_auto_init(p, nt->ExpectShortHandInit)));
		ELSE
			inits := help::parse_initialisers(p);

		p.expect(:semicolon);

		= :a(nt->Name.Content, nt->Name.Position, &&nt->Type, &&inits);
	}

	parse_extern(
		p: Parser&,
		linkName: tok::Token - std::Vec - std::Opt
	) ast::[Config]ExternVariable - std::Opt
	{
		_: Trace(&p, "extern variable");

		IF:!(nt ::= help::parse_uninitialised_name_and_type(p))
			= NULL;
		p.expect(:semicolon);
		= :a(&&nt->Name.Content, nt->Name.Position, &&nt->Type, &&linkName);
	}

	parse_member(
		p: Parser&,
		static: BOOL,
		member_var_index: UM *
	) ast::[Config]MaybeAnonMemberVar - std::ValOpt
	{
		_: Trace(&p, "member variable");

		IF(static)
		{
			IF(nt ::= help::parse_initialised_name_and_type(p))
			{
				inits: ast::[Config]Expression - std::ValVec - std::Opt;

				IF(<<ast::type::[Config]Auto #*>>(nt->Type))
					inits := :a(:vec(
						help::parse_auto_init(p, nt->ExpectShortHandInit)));
				ELSE
					inits := help::parse_initialisers(p);

				p.expect(:semicolon);

				v: ast::[Config]StaticMemberVariable (BARE);
				v.Name := nt->Name.Content;
				v.Type := &&nt->Type;
				v.InitValues := &&inits;
				= :dup(&&v);
			} ELSE = NULL;
		}
		ELSE
		{
			ASSERT(member_var_index != NULL);

			IF(nt ::= help::parse_uninitialised_name_and_type(p))
			{
				p.expect(:semicolon);

				v: ast::[Config]MemberVariable (BARE);
				v.Name := nt->Name.Content;
				v.Type := &&nt->Type;
				v.Index := (*member_var_index)++;
				= :dup(&&v);
			} ELSE IF(help::is_optionally_named_variable_start(p))
			{	// Anonymous member variable.
				IF:!(t ::= type::parse(p))
					p.fail("expected type");
				p.expect(:semicolon);

				v: ast::[Config]AnonMemberVariable (BARE);
				v.Type := :!(&&t);
				v.Index := (*member_var_index)++;

				= :dup(&&v);
			} ELSE = NULL;
		}
	}

	parse_catch(p: Parser &) ast::[Config]TypeOrCatchVariable - std::ValOpt
	{
		_: Trace(&p, "catch variable");

		IF(nt ::= help::parse_uninitialised_name_and_type(p))
		{
			= :a.ast::[Config]CatchVariable(
				&&nt->Name.Content,
				nt->Name.Position,
				p.add_local(),
				:<>(&&nt->Type));
		} ELSE IF(help::is_optionally_named_variable_start(p))
		{	// Anonymous catch variable.
			IF:!(t ::= type::parse(p))
				p.fail("expected type");
			= &&t;
		}
		= NULL;
	}

	parse_local(
		p: Parser &,
		expect_semicolon: BOOL) ast::[Config]LocalVariable - std::ValOpt
	{
		IF:!(nt ::= help::parse_initialised_name_and_type(p))
			= NULL;

		_: Trace(&p, "local variable");

		inits: ast::[Config]Expression - std::ValVec-std::Opt;

		IF(<<ast::type::[Config]Auto #*>>(nt->Type))
			inits := :a(:vec(
				help::parse_auto_init(p, nt->ExpectShortHandInit)));
		ELSE
			inits := help::parse_initialisers(p);

		IF(expect_semicolon)
			p.expect(:semicolon);

		= :a(
			nt->Name.Content,
			nt->Name.Position,
			p.add_local(),
			&&nt->Type,
			&&inits);
	}

	parse_fn_arg(
		p: Parser&
	) ast::[Config]TypeOrArgument-std::ValOpt
	{
		IF:!(nt ::= help::parse_variable_opt_name_and_type(p))
			= NULL;

		IF(nt->Name)
			= :a.ast::[Config]Argument(
				nt->Name->Content, nt->Name->Position, &&nt->Type);
		ELSE
			= :cast_val(&&nt->Type);
	}

	::help needed_without_name: tok::Type#[](
		:bracketOpen, :braceOpen,
		:doubleColon, :colon,
		:void, :bool, :char, :int, :uint, :sm, :um, :null);

	// (token, acceptableIfNeedsName)
	::help needed_after_name: {tok::Type, BOOL}#[](
		(:colon, TRUE),
		(:doubleColonEqual, TRUE),
		(:hash, TRUE),
		(:dollar, TRUE),
		(:exclamationMark, FALSE),
		(:amp, FALSE),
		(:doubleAmp, FALSE),
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
		FOR(i ::= 0; i < ##help::needed_without_name; i++)
			IF(p.match(help::needed_without_name[i]))
				= TRUE;
		= FALSE;
	}

	::help UninitialisedNameAndType
	{
		Name: tok::Token;
		Type: ast::[Config]Type - std::Val;

		{...};
	}

	/// A named uninitialised variable.
	::help parse_uninitialised_name_and_type(
		p: Parser &
	) UninitialisedNameAndType - std::Opt
	{
		IF(!is_named_variable_start(p, TRUE))
			= NULL;

		name ::= p.consume(:identifier)!;
		p.expect(:colon);
		= :a(name, type::parse_x(p));
	}


	::help NameAndInitType
	{
		Name: tok::Token;
		Type: ast::[Config]MaybeAutoType - std::Val;
		ExpectShortHandInit: BOOL;

		{...};
	}
	::help parse_initialised_name_and_type(
		p: Parser &
	) NameAndInitType - std::Opt
	{
		IF(!is_named_variable_start(p, TRUE))
			= NULL;

		name ::= p.expect(:identifier);

		// "name: type" style variable?
		IF(p.consume(:colon))
		{
			IF(p.consume(:questionMark))
			{
				auto: ast::type::[Config]Auto;
				type::parse_auto(p, auto);
				= :a(name, :dup(&&auto), FALSE);
			}
			= :a(name, :<>(type::parse_x(p)), FALSE);
		} ELSE
		{
			STATIC k_need_ahead: tok::Type#[](
				:hash,
				:dollar,
				:doubleColonEqual);

			FOR(i ::= 0; i < ##k_need_ahead; i++)
			{
				IF(p.match(k_need_ahead[i]))
				{
					auto: ast::type::[Config]Auto;
					type::parse_auto_no_ref(p, auto);
					= :a(name, :dup(&&auto), TRUE);
				}
			}
			p.fail("dying, expected #, $, or ::=.");
		}

		DIE;
	}

	::help OptNameAndType
	{
		Name: tok::Token - std::Opt;
		Type: ast::[Config]Type - std::Val;

		{...}; // Suppress {}.
	}

	::help parse_variable_opt_name_and_type(
		p: Parser &
	) OptNameAndType - std::Opt
	{
		IF(p.match_seq(:identifier, :colon))
		{
			name ::= p.consume(:identifier)!;
			p.eat_token()!;
			= :a(:a(name), type::parse_x(p));
		}

		IF(t ::= type::parse(p))
			= :a(NULL, :!(&&t));
		= NULL;
	}

	::help parse_auto_init(p: Parser &, shortHand: BOOL) ast::[Config]Expression-std::Val
	{
		IF(shortHand) p.expect(:doubleColonEqual);
		ELSE p.expect(:colonEqual);

		IF:!(init ::= expression::parse(p))
			p.fail("expected expression");
		= :!(&&init);
	}

	::help parse_initialisers(
		p: Parser &
	) ast::[Config]Expression - std::ValVec - std::Opt
	{
		inits: ast::[Config]Expression - std::ValVec - std::Opt;
		IF(p.consume(:colonEqual))
		{
			IF(!p.consume(:noinit))
				inits := :a(:vec(expression::parse_x(p)));
		}
		ELSE IF(p.consume(:parentheseOpen))
		{
			IF(p.consume(:noinit))
				p.expect(:parentheseClose);
			ELSE
			{
				inits := :a;
				IF(!p.consume(:parentheseClose))
				{
					DO()
						*inits += expression::parse_x(p);
						WHILE(p.consume(:comma))
					p.expect(:parentheseClose);
				}
			}
		} ELSE
			inits := :a;
		= &&inits;
	}
}