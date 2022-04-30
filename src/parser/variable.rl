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

	parse_member(p: Parser&, out: ast::[Config]MemberVariable &, static: BOOL) BOOL
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

	parse_catch(p: Parser &, out: ast::[Config]LocalVariable &) BOOL := parse_fn_arg(p, out);

	parse_local(p: Parser &, out: ast::[Config]LocalVariable &, expect_semicolon: BOOL) BOOL
	{
		IF(!parse_var_decl(p, out))
			= FALSE;
		IF(expect_semicolon)
			p.expect(:semicolon);
		= TRUE;
	}

	parse_fn_arg(p: Parser&, out: ast::[Config]Variable &) [Stage]TypeOrArgument-std::Dyn
	{
		DIE;
	}

	parse_var_decl(p: Parser &, out: ast::[Config]Variable &) BOOL
		:= parse(p, out, TRUE, TRUE, FALSE);

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

	::help parse_variable_name_and_type(
		p: Parser &,
		allow_initialiser: BOOL
	) {
		tok::Token - std::Opt,
		ast::[Config]Type - std::Dyn
	} {
		name: tok::Token;
		IF(p.match(:identifier))
		{
			// "name: type" style variable?
			IF(p.match_ahead(:colon))
			{
				has_name := TRUE;

				p.expect(:identifier, &name);
				p.consume(NULL);

				IF(p.consume(:questionMark))
				{
					auto: type::[Config]Auto;
					parse_auto(p, auto);
					p.expect(:colonEqual);
					= (:a(&&name), :dup(&&auto));
				}
			} ELSE IF(allow_initialiser)
			{
				STATIC k_need_ahead: tok::Type#[](
					:hash,
					:dollar,
					:doubleColonEqual);

				FOR(i ::= 0; i < ##k_need_ahead; i++)
				{
					IF(p.match_ahead(k_need_ahead[i]))
					{
						auto: Auto;
						p.expect(:identifier, &name);
						parse_auto_no_ref(p, auto);
						p.expect(:doubleColonEqual);
						= (:a(name), :dup(&&auto));
					}
				}
			}
		} // If !isArgument, "name: type" is expected.
	}

	parse(
		p: Parser&,
		out: ast::[Config]Variable &,
		needs_name: BOOL,
		allow_initialiser: BOOL,
		force_initialiser: BOOL) BOOL
	{
		IF(needs_name)
		{
			IF(!is_named_variable_start(p, TRUE))
				= FALSE;
		} ELSE IF(!is_optionally_named_variable_start(p))
			= FALSE;

		needs_type ::= TRUE;
		has_name ::= FALSE;

		t: Trace(&p, "variable");

		...;

		IF(!has_name && needs_name)
			= FALSE;

		out.Name := has_name
			? name.Content
			: (p.position(), 0);


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