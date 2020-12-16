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

		# CONVERT(bool!) INLINE := V;

		[T:TYPE] ASSIGN(v: T!&&) VariableType &
			:= std::help::custom_assign(*THIS, __cpp_std::[T!]forward(v));
	}

	Variable -> VIRTUAL ScopeItem
	{
		Name: src::String;
		Type: VariableType;
		HasInitialiser: bool;
		InitValues: std::[std::[Expression]Dynamic]Vector;

		# FINAL name() src::String#& := Name;

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
				tok::Type::bracketOpen,
				tok::Type::doubleColon,
				tok::Type::void);

			STATIC k_needed_after_name: std::[tok::Type, bool]Pair#[](
				std::pair(tok::Type::colon, TRUE),
				std::pair(tok::Type::colonEqual, TRUE),
				std::pair(tok::Type::doubleColonEqual, TRUE),
				std::pair(tok::Type::hash, TRUE),
				std::pair(tok::Type::dollar, TRUE),
				std::pair(tok::Type::exclamationMark, FALSE),
				std::pair(tok::Type::and, FALSE),
				std::pair(tok::Type::doubleAnd, FALSE),
				std::pair(tok::Type::asterisk, FALSE),
				std::pair(tok::Type::backslash, FALSE),
				std::pair(tok::Type::at, FALSE),
				std::pair(tok::Type::doubleAt, FALSE),
				std::pair(tok::Type::doubleDotExclamationMark, FALSE),
				std::pair(tok::Type::doubleDotQuestionMark, FALSE),
				std::pair(tok::Type::doubleColon, FALSE),
				std::pair(tok::Type::semicolon, FALSE),
				std::pair(tok::Type::comma, FALSE),
				std::pair(tok::Type::parentheseClose, FALSE));

			IF(needs_name
			&& !p.match(tok::Type::identifier))
				RETURN FALSE;

			{
				found ::= FALSE;
				IF(p.match(tok::Type::identifier))
				{
					FOR(i ::= 0; i < ::size(k_needed_after_name); i++)
						IF((!needs_name || k_needed_after_name[i].Second)
						&& p.match_ahead(k_needed_after_name[i].First))
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
			IF(p.match(tok::Type::identifier))
			{
				// "name: type" style variable?
				IF(p.match_ahead(tok::Type::colon))
				{
					has_name := TRUE;
					p.expect(tok::Type::identifier, &name);
					p.consume(NULL);
				} ELSE IF(allow_initialiser)
				{
					STATIC k_need_ahead: tok::Type#[](
						tok::Type::hash,
						tok::Type::dollar,
						tok::Type::doubleColonEqual);

					FOR(i ::= 0; i < ::size(k_need_ahead); i++)
					{
						IF(p.match_ahead(k_need_ahead[i]))
						{
							p.expect(tok::Type::identifier, &name);

							Type := ::[Type::Auto]new();
							Type.auto()->Qualifier.parse(p);

							// "name ::=" style variable?
							p.expect(tok::Type::doubleColonEqual);

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
				: src::String::empty;


			IF(!needs_type)
			{
				init ::= Expression::parse(p);
				IF(!init)
					p.fail("expected expression");
				InitValues.push_back(init);
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
					IF(p.consume(tok::Type::colonEqual)
					|| (isParenthese := p.consume(tok::Type::parentheseOpen)))
					{
						// check for empty initialiser.
						IF(!isParenthese
						|| !p.consume(tok::Type::parentheseClose))
						{
							DO()
							{
								arg ::= Expression::parse(p);
								IF(!arg)
									p.fail("expected expression");
								InitValues.push_back(arg);
							} WHILE(isParenthese && p.consume(tok::Type::comma))

							IF(isParenthese)
								p.expect(tok::Type::parentheseClose);
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
		# FINAL type() Global::Type := Global::Type::variable;
		parse(p: Parser&) bool
		{
			IF(!parse_var_decl(p))
				RETURN FALSE;
			p.expect(tok::Type::semicolon);
			RETURN TRUE;
		}

		parse_extern(p: Parser&) bool
		{
			IF(!Variable::parse_extern(p))
				RETURN FALSE;
			p.expect(tok::Type::semicolon);
			RETURN TRUE;
		}
	}

	MemberVariable -> Member, Variable
	{
		# FINAL type() Member::Type := Member::Type::variable;
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
			p.expect(tok::Type::semicolon);
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
				p.expect(tok::Type::semicolon);
			RETURN TRUE;
		}
	}
}