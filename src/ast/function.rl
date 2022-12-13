INCLUDE "global.rl"
INCLUDE "member.rl"
INCLUDE "variable.rl"
INCLUDE "name.rl"
INCLUDE "templatedecl.rl"
INCLUDE "statement.rl"


::rlc::ast [Stage:TYPE] FnSignature VIRTUAL -> [Stage]ScopeBase
{
	Arguments: [Stage]TypeOrArgument-std::DynVec;
	IsCoroutine: BOOL;

	#? FINAL scope_item(Stage::Name #&) [Stage]ScopeItem #? * := NULL;

	#? FINAL local(name: Stage::Name #&, LocalPosition) [Stage]ScopeItem #? *
	{
		FOR(arg ::= Arguments.start().ok())
			IF(named ::= <<[Stage]Argument #? *>>(&arg!))
				IF(named->Name == name)
					= named;
		= NULL;
	}

	<<<
		p: [Stage::Prev+]FnSignature #&,
		ctx: Stage::Context+ #&
	>>> THIS-std::Dyn
	{
		TYPE SWITCH(p)
		{
		[Stage::Prev+]UnresolvedSig:
			= :a.[Stage]UnresolvedSig(:transform(>>p, ctx));
		[Stage::Prev+]ResolvedSig:
			= :a.[Stage]ResolvedSig(:transform(>>p, ctx));
		}
	}

	{...};

	:transform {
		p: [Stage::Prev+]FnSignature #&,
		ctx: Stage::Context+ #&
	}:
		Arguments := :reserve(##p.Arguments),
		IsCoroutine := p.IsCoroutine
	{
		FOR(a ::= p.Arguments.start())
			Arguments += :make(a!, ctx);
	}
}

::rlc::ast [Stage:TYPE] UnresolvedSig -> [Stage]FnSignature
{
	Return: type::[Stage]Auto;

	:transform {
		p: [Stage::Prev+]UnresolvedSig #&,
		ctx: Stage::Context+ #&
	} -> (:transform, p, ctx):
		Return := :transform(p.Return);
}

::rlc::ast [Stage:TYPE] ResolvedSig -> [Stage]FnSignature
{
	Return: [Stage]Type-std::Dyn;

	{
		args: [Stage]TypeOrArgument-std::DynVec&&,
		isCoroutine: BOOL,
		return: [Stage]Type-std::Dyn
	} -> (&&args, isCoroutine): Return := &&return;

	:transform{
		p: [Stage::Prev+]ResolvedSig #&,
		ctx: Stage::Context+ #&
	} -> (:transform, p, ctx):
		Return := :make(p.Return!, ctx);
}

/// An anonymous function object.
::rlc::ast [Stage:TYPE] Functoid VIRTUAL ->
	[Stage]Templateable,
	CodeObject
{
	Signature: [Stage]FnSignature - std::Dyn;
	Body: [Stage]ExprOrStatement - std::DynOpt;
	IsInline: BOOL;

	:transform{
		p: [Stage::Prev+]Functoid #&,
		ctx: Stage::Context+ #&
	} -> (:transform, p, ctx), (p):
		Signature := :make(p.Signature!, ctx),
		Body := :make_if(p.Body, p.Body.ok(), ctx.in_parent(&p.Signature!, &Signature!)),
		IsInline := p.IsInline;

	STATIC short_hand_body(e: [Stage]Expression-std::Dyn) [Stage]Statement-std::Dyn
		:= :a.[Stage]ReturnStatement(:exp(&&e));
}

::rlc::ast VariantMergeError -> Error
{
	FnName: std::str::CV;

	VarName: std::str::CV -std::Opt;
	OldPos: src::Position;

	[Stage: TYPE] {
		fn: [Stage!]Function #&,
		old: [Stage!]Functoid #&,
		new: [Stage!]Functoid #&
	} -> (new.Position):
		FnName := fn.Name!++,
		OldPos := old.Position
	{
		IF(old_var ::= <<[Stage]Variant #*>>(&old))
			VarName := :a(old_var->Name!++);
	}

	# FINAL message(o: std::io::OStream &) VOID
	{
		std::io::write(o, FnName!++);
		IF(VarName)
			std::io::write(o, " ", VarName!++);

		std::io::write(o,
			"() redefined.\n",
			:stream(OldPos), ": previously defined here.");
	}

}

::rlc::ast::function ENUM SpecialVariant {
	null
}

(// A named function with potential callable variants. /)
::rlc::ast [Stage:TYPE] Function VIRTUAL -> [Stage]MergeableScopeItem
{
	Default: [Stage]DefaultVariant-std::Shared;

	SpecialVariants: std::[function::SpecialVariant; ast::[Stage]SpecialVariant-std::Shared]Map;
	(// The function's variant implementations. /)
	Variants: std::[Stage-Name; [Stage]Variant-std::Shared]Map;

	:transform {
		p: [Stage::Prev+]Function #&,
		ctx: Stage::Context+ #&
	} -> (:transform, p, ctx)
	{
		IF(p.Default)
			Default := :a(:transform(p.Default!, ctx));
		FOR(var ::= p.SpecialVariants.start())
			SpecialVariants.insert(var!.Key, :a(:transform(var!.Value!, ctx)));
		FOR(var ::= p.Variants.start())
			Variants.insert(
				ctx.transform_name(var!.Key),
				:a(:transform(var!.Value!, ctx)));
	}

	# THIS<>(rhs: THIS #&) S1 := THIS.Name <> rhs.Name;

	set_templates_after_parsing(tpl: [Stage]TemplateDecl &&) VOID
	{
		IF(Default)
			<[Stage]TemplateDecl &>(Default->Templates) := &&tpl;
		ELSE IF(##SpecialVariants)
			<[Stage]TemplateDecl &>(SpecialVariants.start()->Value->Templates) := &&tpl;
		ELSE
			<[Stage]TemplateDecl &>(Variants.start()->Value->Templates) := &&tpl;
	}

	PRIVATE FINAL merge_impl(rhs: [Stage]MergeableScopeItem &&) VOID
	{
		from: ?& := <<[Stage]Function &>>(rhs);
		IF(from.Default)
		{
			IF(Default)
				THROW <MergeError>(&THIS, &from);
			Default := from.Default;
		}

		FOR(var ::= from.Variants.start())
		{
			IF(prev ::= Variants.find(var!.Key))
				IF(&(prev)! != &var!.Value!)
					THROW <VariantMergeError>(
						THIS, prev!, var!.Value!);
			Variants.insert(&&var!.Key, &&var!.Value);
		}
	}

	PRIVATE FINAL include_impl(rhs: [Stage]MergeableScopeItem #&) VOID
	{
		fn:?#& := <<[Stage]Function #&>>(rhs);
		IF(Default && fn.Default)
			THROW <VariantMergeError>(THIS, Default!, fn.Default!);
	}
}

/// Global function.
::rlc::ast [Stage:TYPE] GlobalFunction -> [Stage]Global, [Stage]Function {
	:transform{
		p: [Stage::Prev+]GlobalFunction #&,
		ctx: Stage::Context+ #&
	} -> (), (:transform, p, ctx);
}

/// A reference to an external function. Cannot have variants.
::rlc::ast [Stage:TYPE] ExternFunction ->
	[Stage]Global,
	[Stage]ScopeItem,
	[Stage]ExternSymbol
{
	Signature: [Stage]ResolvedSig;

	{
		name: Stage::Name,
		position: src::Position,
		signature: [Stage]ResolvedSig &&,
		linkName: Stage::StringLiteral+ - std::Opt
	} -> (), (&&name, position), (&&linkName):
		Signature(&&signature);

	:transform{
		p: [Stage::Prev+]ExternFunction #&,
		ctx: Stage::Context+ #&
	} -> (), (:transform, p, ctx), (:transform, p, ctx):
		Signature := :transform(p.Signature, ctx);
}

::rlc::ast [Stage:TYPE] DefaultVariant -> [Stage]Functoid {
	:transform{
		p: [Stage::Prev+]DefaultVariant #&,
		ctx: Stage::Context+ #&
	} -> (:transform, p, ctx);
}
::rlc::ast [Stage:TYPE] SpecialVariant -> [Stage]Functoid {
	Variant: function::SpecialVariant;

	:transform{
		p: [Stage::Prev+]SpecialVariant #&,
		ctx: Stage::Context+ #&
	} -> (:transform, p, ctx):
		Variant := p.Variant;
}
::rlc::ast [Stage:TYPE] Variant -> [Stage]Functoid {
	Name: Stage::Name+;

	:transform{
		p: [Stage::Prev+]Variant #&,
		ctx: Stage::Context+ #&
	} -> (:transform, p, ctx):
		Name := ctx.transform_name(p.Name);
}

::rlc ENUM Abstractness
{
	none,
	virtual,
	abstract,
	override,
	final
}

/// All functions that can be abstracted: functions, operators, converters.
::rlc::ast [Stage:TYPE] Abstractable VIRTUAL -> [Stage]Member
{
	Abstractness: rlc::Abstractness;

	:transform{
		p: [Stage::Prev+]Abstractable #&
	} -> (:transform, p):
		Abstractness := p.Abstractness;


	<<<
		p: [Stage::Prev+]Abstractable #&,
		ctx: Stage::Context+ #&
	>>> THIS - std::Dyn
	{
		TYPE SWITCH(p)
		{
		[Stage::Prev+]Converter:
			= :a.[Stage]Converter(:transform(
				<<[Stage::Prev+]Converter #&>>(p), ctx));
		[Stage::Prev+]MemberFunction:
			= :a.[Stage]MemberFunction(:transform(
				<<[Stage::Prev+]MemberFunction #&>>(p), ctx));
		[Stage::Prev+]Operator:
			= :a.[Stage]Operator(:transform(
				<<[Stage::Prev+]Operator #&>>(p), ctx));
		}
	}
}

(// Type conversion operator. /)
::rlc::ast [Stage:TYPE] Converter -> [Stage]Abstractable, [Stage]Functoid
{
	:transform{
		p: [Stage::Prev+]Converter #&,
		ctx: Stage::Context+ #&
	} -> (:transform, p), (:transform, p, ctx);

	# type() [Stage]Type #\ INLINE := &*<<[Stage]ResolvedSig #\>>(THIS.Signature)->Return;

	// Make converters unique per type.
	# THIS<>(rhs: THIS#&) S1 := *type() <> *rhs.type();
}

::rlc::ast [Stage:TYPE] MemberFunction -> [Stage]Abstractable, [Stage]Function
{
	:transform{
		p: [Stage::Prev+]MemberFunction #&,
		ctx: Stage::Context+ #&
	} -> (:transform, p), (:transform, p, ctx);

	# THIS <> (rhs: THIS #&) S1 INLINE
		:= <[Stage]Function&>(THIS) <> <[Stage]Function&>(rhs);
}

/// Custom operator implementation.
::rlc::ast [Stage:TYPE] Operator -> [Stage]Abstractable, [Stage]Functoid
{
	Op: rlc::Operator;

	:transform{
		p: [Stage::Prev+]Operator #&,
		ctx: Stage::Context+ #&
	} -> (:transform, p), (:transform, p, ctx):
		Op := p.Op;

	# THIS <> (rhs: THIS #&) S1 := <S1>(Op) <> <S1>(rhs.Op);
}

::rlc::ast [Stage:TYPE] Factory -> [Stage]Member, [Stage]Functoid
{
	:transform{
		p: [Stage::Prev+]Factory #&,
		ctx: Stage::Context+ #&
	} -> (:transform, p), (:transform, p, ctx);
}