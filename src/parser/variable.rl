INCLUDE "parser.rl"
INCLUDE "type.rl"
INCLUDE "symbol.rl"
INCLUDE "global.rl"
INCLUDE "member.rl"

INCLUDE 'std/memory'
INCLUDE 'std/vector'

::rlc::parser
{
	Variable -> VIRTUAL ScopeItem
	{
		Name: src::String;
		HasType: bool;
		Type: std::[parser::Type]Dynamic;
		HasInitialiser: bool;
		InitValues: std::[std::[Expression]Dynamic]Vector;
		TypeQualifier: Type::Qualifier;

		# FINAL name() src::String#& := Name;

		parse_fn_arg(p: Parser&) bool
			:= parse(p, FALSE, TRUE, FALSE);
		parse_var_decl(p: Parser &) bool
			:= parse(p, TRUE, TRUE, FALSE);

		parse(p: Parser&,
			needs_name: bool,
			allow_initialiser: bool,
			force_initialiser: bool) bool
		{
			STATIC k_needed_without_name: tok::Type#[](
				tok::Type::bracketOpen,
				tok::Type::doubleColon);

			STATIC k_needed_after_name: std::[tok::Type, bool]Pair#[](
				std::pair(tok::Type::colon, TRUE),
				std::pair(tok::Type::colonEqual, TRUE),
				std::pair(tok::Type::doubleColonEqual, TRUE),
				std::pair(tok::Type::hash, TRUE),
				std::pair(tok::Type::dollar, TRUE),
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
					FOR(i ::= 0; i < ::size(k_needed_after_name); i++)
						IF((!needs_name || k_needed_after_name[i].Second)
						&& p.match_ahead(k_needed_after_name[i].First))
						{
							found := TRUE;
							BREAK;
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

							TypeQualifier.parse(p);

							// "name ::=" style variable?
							p.expect(tok::Type::doubleColonEqual);

							has_name := TRUE;
							needs_type := FALSE;
							HasType := FALSE;
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
				IF(!(Type := parser::Type::parse(p)).Ptr)
				{
					IF(needs_name)
						p.fail("expected name");
					ELSE
						RETURN FALSE;
				}

				HasType := TRUE;

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
		parse(p: Parser&) INLINE ::= Variable::parse_var_decl(p);
	}

	MemberVariable -> Member, Variable
	{
		# FINAL type() Member::Type := Member::Type::variable;
		parse(p: Parser&) INLINE ::= Variable::parse_var_decl(p);
	}

	TYPE LocalVariable := GlobalVariable;
}