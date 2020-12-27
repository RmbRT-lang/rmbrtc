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
			{};
			{
				type: TemplateDeclType,
				name: src::String #&}:
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
			IF(!p.consume(:bracketOpen))
				RETURN FALSE;

			IF(!p.consume(:bracketClose))
			{
				DO()
				{
					c: Child;
					name: tok::Token;
					p.expect(:identifier, &name);
					c.Name := name.Content;
					p.expect(:colon);

					IF(p.consume(:type))
						c.Type := :type;
					ELSE IF(p.consume(:number))
						c.Type := :number;
					ELSE IF(c.TypeName := :gc(Type::parse(p)))
						c.Type := :value;
					ELSE
						p.fail("expected 'TYPE', 'NUMBER', or type");

					Children += &&c;
				} WHILE(p.consume(:comma))

				p.expect(:bracketClose);
			}

			RETURN TRUE;
		}

		# exists() bool := Children.size() != 0;
	}
}