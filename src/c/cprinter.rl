INCLUDE  "../instantiator/stage.rl"
INCLUDE "../instantiator/type.rl"
INCLUDE "../instantiator/expression.rl"
INCLUDE "../instantiator/function.rl"

::rlc::instantiator CPrinter -> VariadicExpansionTracker
{
	TYPE PrevType := ast::[resolver::Config]Type;
	TYPE Type := ast::[Config]Type;

	ThisConstness: BOOL-std::Opt; /// For member functions, tracks the constness of the THIS type.
	Cache: instantiator::Cache;

	TypeDecls: std::StreamBuffer;
	TypeImpls: std::StreamBuffer;
	FnDecls: std::StreamBuffer;
	Vars: std::StreamBuffer;
	FnImpls: std::StreamBuffer;

	this_type(p: InstanceID #\, ofExpression: BOOL) InstanceType
	{
		WHILE(p && !(<<ast::[resolver::Config]CoreType #*>>(p->Descriptor)))
			p := p->Parent;
		IF(!p)
			THROW <rlc::ReasonError>(
				<<ast::CodeObject #\>>(p->Descriptor)->Position,
				"contains a THIS type despite not being in a class");
		t: InstanceType := p;
		IF(ofExpression)
		{
			IF(THIS.ThisConstness)
				t.Modifiers += :const;
			t.Reference := :reference;
		}
		= &&t;
	}

	print_statement(
		stmt: ast::[resolver::Config]Statement #&,
		ctx: StatementContext #&
	) std::StreamBuffer
	{
		TYPE SWITCH(stmt)
		{
		ast::[resolver::Config]IfStatement: {;}
		}

		DIE "print_statement";
	}

	print_instance_name(o: std::io::OStream &, i: InstanceID #\) VOID { DIE "print_instance_name"; }

	print_type(
		o: std::io::OStream &,
		type: ast::[Config]Type #&
	) VOID { DIE "print_type"; }

	print_fn_decl(
		o: std::io::OStream &,
		ctx: FunctionContext #&,
		is_decl: BOOL
	) VOID
	{
		fn# ::= <<ast::[resolver::Config]Functoid #\>>(ctx.Function->Descriptor);

		IF(fn->IsInline && is_decl)
			std::io::write(o, "inline ");

		print_type(o, ctx.resolved_ret_type());
		std::io::write(o, " ");
		print_instance_name(o, ctx.Function);
		std::io::write(o, "(");
		firstArg ::= TRUE;
		FOR(arg ::= fn->Signature!.Args!.start())
		{
			IF(firstArg) { firstArg := FALSE; std::io::write(o, ", "); }

			print_type(o, ctx.Args.find(&arg!)!);

			IF(!is_decl)
				IF(named ::= <<ast::[resolver::Config]Argument #*>>(&arg!))
					std::io::write(o, " ", named->Name!++);
		}
		std::io::write(o, ")");

		IF(is_decl)
			std::io::write(o, ";\n");
	}

	generate_class(instance: Instance \) VOID
	{
	}

	/// Either a fully resolved symbol or the last symbol is unresolved in case of functions.
	ValueSymbol
	{
		Parent: Instance #*;
		Tail: ast::[resolver::Config]ScopeItem #*;
		TailTpl: ast::[Config]TemplateArg -std::Vec;
	}
}