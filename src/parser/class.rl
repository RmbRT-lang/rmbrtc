INCLUDE "stage.rl"

INCLUDE "parser.rl"
INCLUDE "member.rl"

INCLUDE "../ast/class.rl"

::rlc::parser::class
{
	parse(p: Parser &, out: Config-ast::Class &) BOOL
	{
		IF(!p.match(:identifier)
		|| (!p.match_ahead(:braceOpen)
			&& !p.match_ahead(:minusGreater)
			&& !p.match_ahead(:virtual)))
			= FALSE;

		t: Trace(&p, "class");

		tok ::= p.expect(:identifier);
		(out.Name, out.Position) := (tok.Content, tok.Position);

		out.Virtual := p.consume(:virtual);

		IF(p.consume(:minusGreater))
			DO(i: ast::class::[Config]Inheritance (BARE))
			{
				parse_inheritance(p, i);

				/// HACK: tolerate quirks of the bootstrap compiler.
				p.consume(:plus);

				out.Inheritances += &&i;
			} WHILE(p.consume(:comma))

		p.expect(:braceOpen);

		default ::= Visibility::public;
		WHILE(member ::= member::parse_class_member(p, default))
		{
			IF(ctor ::= <<ast::[Config]Constructor *>>(member!))
			{
				TYPE SWITCH(ctor)
				{
				ast::[Config]StructuralConstructor:
					IF(out.StructuralCtor)
						p.fail("multiple structural constructors");
					ELSE out.StructuralCtor := &&member;
				ast::[Config]DefaultConstructor:
					IF(out.DefaultCtor)
						p.fail("multiple default constructors");
					ELSE out.DefaultCtor := &&member;
				ast::[Config]CopyConstructor:
					IF(out.CopyCtor)
						p.fail("multiple copy constructors");
					ELSE out.CopyCtor := &&member;
				ast::[Config]MoveConstructor:
					IF(out.MoveCtor)
						p.fail("multiple copy constructors");
					ELSE out.MoveCtor := &&member;
				ast::[Config]CustomConstructor:
					/// Cannot enter them into the ctor set yet because src strings are not comparable. This has to be done at the next stage.
					out.Members += &&member;
				}
			} ELSE
				out.Members += &&member;
		}

		p.expect(:braceClose);

		= TRUE;
	}

	parse_inheritance(p: Parser &, out: ast::class::[Config]Inheritance &) VOID
	{
		STATIC lookup: {tok::Type, rlc::Visibility}#[](
			(:public, :public),
			(:private, :private),
			(:protected, :protected));

		t: Trace(&p, "inheritance");

		out.Visibility := :public;
		FOR(i ::= 0; i < ##lookup; i++)
			IF(p.consume(lookup[i].(0)))
			{
				out.Visibility := lookup[i].(1);
				BREAK;
			}

		out.IsVirtual := p.consume(:virtual);

		IF(!symbol::parse(p, out.Type))
			p.fail("expected type");
	}

	parse_member(p: Parser &, out: ast::[Config]MemberClass &) BOOL
		:= parse(p, out);
	parse_global(p: Parser &, out: ast::[Config]GlobalClass &) BOOL
		:= parse(p, out);
}