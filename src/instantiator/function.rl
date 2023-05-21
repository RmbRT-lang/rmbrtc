INCLUDE "context.rl"
INCLUDE "ortype.rl"

/// Binding of instantiated argument types to name-resolved arguments.
::rlc::instantiator TYPE ArgTypes := ast::[Config]Type-std::Val -
		std::[ast::[resolver::Config]TypeOrArgument #\]Map;

/// The return type of a function, as it is being generated.
::rlc::instantiator GeneratingReturnType
{
	:parse{type: ast::[Config]MaybeAutoType -std::Val &&}:
		Auto (NOINIT),
		RetType (NOINIT)
	{
		IF(auto ::= <<ast::type::[Config]Auto *>>(type.mut_ptr()))
		{
			Auto.{:a(&&*auto)};
			RetType.{:a.OrType()};
		}
		ELSE
		{
			Auto.{NULL};
			RetType.{:<>(&&type)};
		}
	}

	/// Whether to determine the return type dynamically. Only add entries to an OrType if this flag is set, to differentiate between explicit OrType return types and auto returns.
	# is_auto() BOOL := Auto;
	/// The modifier to add to the return values in an auto-returning function.
	Auto: ast::type::[Config]Auto -std::Opt;
	/// The actual return type. Depending on is_auto(), it needs to be constructed during the function's generation.
	RetType: ast::[Config]Type-std::Val;
}

/// The function we're currently in, if any.
::rlc::instantiator FunctionContext -> Context
{
	ConstThis: BOOL;

	:childOf{
		p: Context #\,
		fn: InstanceID #\,
		args: ArgTypes &&,
		ret: ast::[Config]MaybeAutoType -std::Val
	} -> (:childOf, p):
		ConstThis := FALSE,
		Function := fn,
		Args := &&args,
		RetType := :parse(&&ret);

	# FINAL this_type() InstanceType
	{
		IF(!THIS.Parent)
			THROW;

		t ::= THIS.Parent->this_type();
		IF(ConstThis)
			t.Modifiers += :const;
		= &&t;
	}

	Function: InstanceID #\;
	Args: ArgTypes;
	RetType: GeneratingReturnType;

	# resolved_ret_type() ast::[Config]Type #& := RetType.RetType!;
}

::rlc::instantiator generate_functoid(instance: InstanceID \, ctx: Context #&) VOID
{
	/// First, go through the function and evaluate its types and statements, determine its return type, then print its declaration and definition.
	fn ::= <<ast::[resolver::Config]Functoid #\>>(instance->Descriptor);
	retType: ast::[Config]MaybeAutoType -std::ValOpt;

	argTypes: ast::[Config]Type - std::[ast::[resolver::Config]TypeOrArgument #\]ValMap := :reserve(##fn->Signature!.Args);
	FOR(arg ::= fn->Signature!.Args.start())
		TYPE SWITCH(arg!)
		{
		ast::[resolver::Config]Type:
			argTypes.insert(&arg!, type::resolve(>>arg!, ctx));
		ast::[resolver::Config]Argument:
			argTypes.insert(&arg!,
				type::resolve(
					<<ast::[resolver::Config]Argument#&>>(arg!).Type!,
					ctx));
		}

	TYPE SWITCH(fn->Signature!)
	{
	ast::[resolver::Config]UnresolvedSig: {
		sig ::= <<ast::[resolver::Config]UnresolvedSig #\>>(fn->Signature);
		retType := :a.ast::type::[Config]Auto(:transform(sig->Return));
	}
	ast::[resolver::Config]ResolvedSig:
	{
		sig ::= <<ast::[resolver::Config]ResolvedSig #\>>(fn->Signature);
		retType := :<>(type::resolve(sig->Return!, ctx));
	}
	}

	fnContext: FunctionContext := :childOf(&ctx, instance, &&argTypes, :!(&&retType));

	IF:!(body ::= <<ast::[resolver::Config]Statement #*>>(&fn->Body!))
		DIE "short-hand expression body";

	IF(ctx.Generator)
		ctx.Generator->generate_functoid(
			fnContext,
			statement::evaluate(*body, fnContext));

	DIE "store the generated function";
}