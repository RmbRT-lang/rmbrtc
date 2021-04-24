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
		PRIVATE V: util::[Type, Type::Auto]DynUnion;

		{};
		{t: Type \}: V(t);
		{t: Type::Auto \}: V(t);

		# is_type() INLINE bool := V.is_first();
		# type() INLINE Type \ := V.first();
		# is_auto() INLINE bool := V.is_second();
		# auto() INLINE Type::Auto \ := V.second();

		# <bool!> INLINE := V;

		[T:TYPE] THIS:=(v: T!&&) VariableType &
			:= std::help::custom_assign(THIS, <T!&&>(v));
	}

	Variable -> VIRTUAL ScopeItem
	{
		Name: src::String;
		Type: VariableType;
		HasInitialiser: bool;
		InitValues: std::[std::[Expression]Dynamic]Vector;

		# FINAL name() src::String#& := Name;
		# FINAL overloadable() bool := !Name.exists();

		parse_fn_arg(p: Parser&) bool
			:= parse(p, FALSE, FALSE, FALSE);
		parse_var_decl(p: Parser &) bool
			:= parse(p, TRUE, TRUE, FALSE);
		parse_extern(p: Parser&) bool
			:= parse(p, TRUE, FALSE, FALSE);

		parse(p: Parser&,
			needs_name: bool,
			allow_initialiser: bool,
			force_initialiser: bool) bool
		{
			STATIC k_needed_without_name: tok::Type#[](
				:bracketOpen,
				:braceOpen,
				:doubleColon,
				:colon,
				:void);

			STATIC k_needed_after_name: {tok::Type, bool}#[](
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
					FOR(i ::= 0; i < ::size(k_needed_after_name); i++)
						IF((!needs_name || k_needed_after_name[i].(1))
						&& p.match_ahead(k_needed_after_name[i].(0)))
						{
							found := TRUE;
							BREAK;
						}
				}
				ELSE
					FOR(i ::= 0; i < ::size(k_needed_without_name); i++)
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
						Type := ::[Type::Auto]new();
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

					FOR(i ::= 0; i < ::size(k_need_ahead); i++)
					{
						IF(p.match_ahead(k_need_ahead[i]))
						{
							p.expect(:identifier, &name);

							Type := ::[Type::Auto]new();
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
				IF(!(Type := parser::Type::parse(p)))
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
		# FINAL type() Global::Type := :variable;
		parse(p: Parser&) bool
		{
			IF(!parse_var_decl(p))
				RETURN FALSE;
			p.expect(:semicolon);
			RETURN TRUE;
		}

		parse_extern(p: Parser&) bool
		{
			IF(!Variable::parse_extern(p))
				RETURN FALSE;
			p.expect(:semicolon);
			RETURN TRUE;
		}
	}

	MemberVariable -> Member, Variable
	{
		# FINAL type() Member::Type := :variable;
		parse(p: Parser&, static: bool) bool
		{
			IF(static)
			{
				IF(!parse_var_decl(p))
					RETURN FALSE;
			}
			ELSE
			{
				IF(!parse_fn_arg(p))
					RETURN FALSE;
			}
			p.expect(:semicolon);
			RETURN TRUE;
		}
	}

	Local -> VIRTUAL ScopeItem
	{
		# FINAL category() ScopeItem::Category := ScopeItem::Category::local;
	}

	LocalVariable -> Local, Variable
	{
		parse(p: Parser &, expect_semicolon: bool) bool
		{
			IF(!Variable::parse_var_decl(p))
				RETURN FALSE;
			IF(expect_semicolon)
				p.expect(:semicolon);
			RETURN TRUE;
		}
	}
}