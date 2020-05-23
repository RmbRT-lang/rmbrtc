INCLUDE "parser.rl"
INCLUDE "expression.rl"
INCLUDE "variable.rl"

INCLUDE 'std/vector'
INCLUDE 'std/memory'

::rlc::parser
{
	ENUM StatementType
	{
		block
	}

	Statement
	{
		# ABSTRACT type() StatementType;

		STATIC parse(p: Parser&) Statement *
		{
			{
				v: BlockStatement;
				IF(v.parse(p))
					RETURN [TYPE(v)]new(__cpp_std::move(v));
			}

			RETURN NULL;
		}
	}

	BlockStatement -> Statement
	{
		Statements: std::[std::[Statement]Dynamic]Vector;

		# FINAL type() StatementType := StatementType::block;

		parse(p: Parser&) bool
		{
			IF(!p.consume(tok::Type::braceOpen))
				RETURN FALSE;

			IF(p.consume(tok::Type::semicolon))
			{
				p.expect(tok::Type::braceClose);
				RETURN TRUE;
			}

			WHILE(!p.consume(tok::Type::braceClose))
			{
				IF(stmt ::= Statement::parse(p))
					Statements.push_back(stmt);
				ELSE
					p.fail("expected statement or '}'");
			}

			RETURN TRUE;
		}
	}
}