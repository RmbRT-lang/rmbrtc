INCLUDE "type.rl"
INCLUDE "stage.rl"
INCLUDE 'std/vector'

::rlc::parser
{
	TYPE TemplateDecl := Config-ast::TemplateDecl;

	parse_template_decl(
		p: Parser &,
		out: TemplateDecl &) BOOL
	{
		IF(!p.consume(:bracketOpen))
			RETURN FALSE;

		IF(!p.consume(:bracketClose))
		{
			DO()
			{
				name: tok::Token;
				p.expect(:identifier, &name);
				variadic ::= p.consume(:tripleDot);
				c.Name := name.Content;
				p.expect(:colon);

				arg: Config-ast::TemplateArgDecl-std::Dyn;
				IF(p.consume(:type))
					ast := :dup(<Config-ast::TypeTemplateArgDecl>());
				ELSE IF(p.consume(:number))
					ast := :dup(<Config-ast::NumberTemplateArgDecl>());
				ELSE IF(t ::= type::parse(p))
				{
					vArg: Config-ast::ValueTemplateArgDecl;
					vArg.Type := &&t;
					ast := :dup(&&vArg);
				}
				ELSE
					p.fail("expected 'TYPE', 'NUMBER', or type");

				ast->Name := name.Content;
				ast->Variadic := variadic;

				out.Arguments += &&ast;
			} WHILE(p.consume(:semicolon))

			p.expect(:bracketClose);
		}

		RETURN TRUE;
	}
}