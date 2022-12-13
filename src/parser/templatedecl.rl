INCLUDE "type.rl"
INCLUDE "stage.rl"
INCLUDE 'std/vector'

::rlc::parser
{
	parse_template_decl(
		p: Parser &,
		out: ast::[Config]TemplateDecl &) BOOL
	{
		IF(!p.consume(:bracketOpen))
			RETURN FALSE;

		IF(!p.consume(:bracketClose))
		{
			DO()
			{
				name ::= p.expect(:identifier).Content;
				variadic ::= p.consume(:tripleDot);
				p.expect(:colon);

				arg: Config-ast::TemplateArgDecl-std::Dyn (BARE);
				IF(p.consume(:type))
					arg := :a.Config-ast::TypeTemplateArgDecl(BARE);
				ELSE IF(p.consume(:number))
					arg := :a.Config-ast::NumberTemplateArgDecl(BARE);
				ELSE IF(t ::= type::parse(p))
				{
					vArg: Config-ast::ValueTemplateArgDecl(BARE);
					vArg.Type := :!(&&t);
					arg := :dup(&&vArg);
				}
				ELSE
					p.fail("expected 'TYPE', 'NUMBER', or type");

				arg->Name := name;
				arg->Variadic := variadic;

				out.Arguments += &&arg;
			} WHILE(p.consume(:semicolon))

			p.expect(:bracketClose);
		}

		RETURN TRUE;
	}
}