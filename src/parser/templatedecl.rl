INCLUDE "type.rl"
INCLUDE "parser.rl"

INCLUDE 'std/vector'

::rlc::parser
{
	ENUM TemplateDeclType
	{
		number,
		type,
		value
	}

	TemplateDecl
	{
		Child
		{
			CONSTRUCTOR();
			CONSTRUCTOR(
				type: TemplateDeclType,
				name: src::String #&):
				Type(type),
				Name(name);

			Type: TemplateDeclType;
			TypeName: std::[parser::Type]Dynamic;
			Name: src::String;
		}
		Children: std::[Child]Vector;

		parse(
			p: Parser &) bool
		{
			IF(!p.consume(tok::Type::bracketOpen))
				RETURN FALSE;

			IF(!p.consume(tok::Type::bracketClose))
			{
				DO()
				{
					c: Child;
					name: tok::Token;
					p.expect(tok::Type::identifier, &name);
					c.Name := name.Content;
					p.expect(tok::Type::colon);

					IF(p.consume(tok::Type::type))
						c.Type := TemplateDeclType::type;
					ELSE IF(p.consume(tok::Type::number))
						c.Type := TemplateDeclType::number;
					ELSE IF((c.TypeName := Type::parse(p)).Ptr)
						c.Type := TemplateDeclType::value;
					ELSE
						p.fail();

					Children.push_back(__cpp_std::move(c));
				} WHILE(!p.consume(tok::Type::comma))

				p.expect(tok::Type::bracketClose);
			}

			RETURN TRUE;
		}

		# exists() bool := Children.size() != 0;
	}
}