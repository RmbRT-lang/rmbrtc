INCLUDE "parser.rl"
INCLUDE "type.rl"
INCLUDE "symbol.rl"
INCLUDE "global.rl"
INCLUDE "member.rl"

INCLUDE 'std/memory'
INCLUDE 'std/vector'

INCLUDE "../util/dynunion.rl"

::rlc::parser
{
	VariableType
	{
		PRIVATE V: util::[Type; Type::Auto]DynUnion;

		{};
		{:gc, t: Type \}: V(:gc(t));
		{:gc, t: Type::Auto \}: V(:gc(t));

		# is_type() INLINE BOOL := V.is_first();
		# type() INLINE Type \ := V.first();
		# is_auto() INLINE BOOL := V.is_second();
		# auto() INLINE Type::Auto \ := V.second();

		# <BOOL> INLINE := V;

		[T:TYPE] THIS:=(v: T!&&) VariableType &
			:= std::help::custom_assign(THIS, <T!&&>(v));
	}

	Variable VIRTUAL -> ScopeItem
	{
		Name: src::String;
		Type: VariableType;
		HasInitialiser: BOOL;
		InitValues: Expression - std::DynVector;

		# FINAL type() ScopeItem::Type := :variable;
		# FINAL name() src::String#& := Name;
		# FINAL overloadable() BOOL := !Name.exists();

		parse_fn_arg(p: Parser&) BOOL
			:= parse(p, FALSE, FALSE, FALSE);
		parse_var_decl(p: Parser &) BOOL
			:= parse(p, TRUE, TRUE, FALSE);
		parse_extern(p: Parser&) BOOL
			:= parse(p, TRUE, FALSE, FALSE);

		parse(p: Parser&,
			needs_name: BOOL,
			allow_initialiser: BOOL,
			force_initialiser: BOOL) BOOL
		{
			STATIC k_needed_without_name: tok::Type#[](
				:bracketOpen,
				:braceOpen,
				:doubleColon,
				:colon,
				:void,
				:bool,
				:char,
				:int,
				:uint,
				:sm,
				:um,
				:null);

			STATIC k_needed_after_name: {tok::Type, BOOL}#[](
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

			IF(needs_name
			&& !p.match(:identifier))
				RETURN FALSE;
			ELSE
			{
				found ::= FALSE;
				IF(p.match(:identifier))
				{
					FOR(i ::= 0; i < ##k_needed_after_name; i++)
						IF((!needs_name || k_needed_after_name[i].(1))
						&& p.match_ahead(k_needed_after_name[i].(0)))
						{
							found := TRUE;
							BREAK;
						}
				}
				ELSE
					FOR(i ::= 0; i < ##k_needed_without_name; i++)
						IF(p.match(k_needed_without_name[i]))
						{
							found := TRUE;
							BREAK;
						}

				IF(!found)
					RETURN FALSE;
			}

			needs_type ::= TRUE;
			has_name ::= FALSE;

			t: Trace(&p, "variable");

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
						Type := :gc(std::[parser::Type::Auto]new());
						Type.auto()->parse(p);
						p.expect(:colonEqual);
						needs_type := FALSE;
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
							p.expect(:identifier, &name);

							Type := :gc(std::[parser::Type::Auto]new());
							Type.auto()->parse(p, FALSE);

							// "name ::=" style variable?
							p.expect(:doubleColonEqual);

							has_name := TRUE;
							needs_type := FALSE;
							BREAK;
						}
					}
				}
			} // If !isArgument, "name: type" is expected.
			IF(!has_name && needs_name)
				RETURN FALSE;

			Name := has_name
				? name.Content
				: (p.position(), 0);


			IF(!needs_type)
			{
				init ::= Expression::parse(p);
				IF(!init)
					p.fail("expected expression");
				InitValues += :gc(init);
			} ELSE
			{
				IF(!(Type := :gc(parser::Type::parse(p))))
				{
					IF(needs_name)
						p.fail("expected name");
					ELSE
						RETURN FALSE;
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
								arg ::= Expression::parse(p);
								IF(!arg)
									p.fail("expected expression");
								InitValues += :gc(arg);
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

			RETURN TRUE;
		}
	}

	GlobalVariable -> Global, Variable
	{
		parse(p: Parser&) BOOL
		{
			IF(!Variable::parse_var_decl(p))
				RETURN FALSE;
			p.expect(:semicolon);
			RETURN TRUE;
		}

		parse_extern(p: Parser&) BOOL
		{
			IF(!Variable::parse_extern(p))
				RETURN FALSE;
			p.expect(:semicolon);
			RETURN TRUE;
		}
	}

	MemberVariable -> Member, Variable
	{
		parse(p: Parser&, static: BOOL) BOOL
		{
			IF(static)
			{
				IF(!Variable::parse_var_decl(p))
					RETURN FALSE;
			}
			ELSE
			{
				IF(!Variable::parse_fn_arg(p))
					RETURN FALSE;
			}
			p.expect(:semicolon);
			RETURN TRUE;
		}
	}

	Local VIRTUAL {}

	LocalVariable -> Local, Variable
	{
		parse(p: Parser &, expect_semicolon: BOOL) BOOL
		{
			IF(!Variable::parse_var_decl(p))
				RETURN FALSE;
			IF(expect_semicolon)
				p.expect(:semicolon);
			RETURN TRUE;
		}

		parse_catch(p: Parser &) BOOL := Variable::parse_fn_arg(p);
	}
}