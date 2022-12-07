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

	<<<
		p: [Stage::Prev+]FnSignature #&,
		f: Stage::PrevFile+,
		s: Stage &,
		parent: [Stage]ScopeBase \
	>>> THIS-std::Dyn
	{
		TYPE SWITCH(p)
		{
		[Stage::Prev+]UnresolvedSig:
			= :a.[Stage]UnresolvedSig(:transform(>>p, f, s, parent));
		[Stage::Prev+]ResolvedSig:
			= :a.[Stage]ResolvedSig(:transform(>>p, f, s, parent));
		}
	}

	{...};

	:transform {
		p: [Stage::Prev+]FnSignature #&,
		f: Stage::PrevFile+,
		s: Stage &,
		parent: [Stage]ScopeBase \
	}:
		Arguments := :reserve(##p.Arguments),
		IsCoroutine := p.IsCoroutine
	{
		FOR(a ::= p.Arguments.start())
			Arguments += :make(a!, f, s, parent);
	}
}

::rlc::ast [Stage:TYPE] UnresolvedSig -> [Stage]FnSignature
{
	Return: type::[Stage]Auto;

	:transform {
		p: [Stage::Prev+]UnresolvedSig #&,
		f: Stage::PrevFile+,
		s: Stage &,
		parent: [Stage]ScopeBase \
	} -> (:transform, p, f, s, parent):
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
		f: Stage::PrevFile+,
		s: Stage &,
		parent: [Stage]ScopeBase \
	} -> (:transform, p, f, s, parent):
		Return := :make(p.Return!, f, s, parent);
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
		f: Stage::PrevFile+,
		s: Stage &,
		parent: [Stage]ScopeBase \
	} -> (:transform, p, f, s, parent), (p):
		Signature := :make(p.Signature!, f, s, &THIS),
		Body := :make_if(p.Body, p.Body.ok(), f, s, &Signature!),
		IsInline := p.IsInline;

	STATIC short_hand_body(e: [Stage]Expression-std::Dyn) [Stage]Statement-std::Dyn
		:= :a.[Stage]ReturnStatement(:exp(&&e));
}

::rlc::ast [Stage: TYPE] VariantMergeError {
	Function: ast::[Stage]Function \;
	Name: Stage::Name;
	Old: [Stage]Variant \;
	New: [Stage]Variant \;
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
		f: Stage::PrevFile+,
		s: Stage &,
		parent: [Stage]ScopeBase \
	} -> (:transform, p, f, s, parent)
	{
		IF(p.Default)
			Default := :a(:transform(p.Default!, f, s, parent));
		FOR(var ::= p.SpecialVariants.start())
			SpecialVariants.insert(var!.Key, :a(:transform(var!.Value!, f, s, parent)));
		FOR(var ::= p.Variants.start())
			Variants.insert(
				s.transform_name(var!.Key, f),
				:a(:transform(var!.Value!, f, s, parent)));
	}

	# THIS<>(rhs: THIS #&) S1 := THIS.Name <> rhs.Name;

	set_templates_after_parsing(tpl: [Stage]TemplateDecl &&) VOID
	{
		IF(Default)
			Default->Templates := &&tpl;
		ELSE IF(##SpecialVariants)
			SpecialVariants.start()->Value->Templates := &&tpl;
		ELSE
			Variants.start()->Value->Templates := &&tpl;
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
					THROW <[Stage]VariantMergeError>(
						&THIS, var!.Key,
						&prev!, &var!.Value!);
			Variants.insert(&&var!.Key, &&var!.Value);
		}
	}
}

/// Global function.
::rlc::ast [Stage:TYPE] GlobalFunction -> [Stage]Global, [Stage]Function {
	:transform{
		p: [Stage::Prev+]GlobalFunction #&,
		f: Stage::PrevFile+,
		s: Stage &,
		parent: [Stage]ScopeBase \
	} -> (), (:transform, p, f, s, parent);
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
		f: Stage::PrevFile+,
		s: Stage &,
		parent: [Stage]ScopeBase \
	} -> (), (:transform, p, f, s), (:transform, p, f, s):
		Signature := :transform(p.Signature, f, s, parent);
}

::rlc::ast [Stage:TYPE] DefaultVariant -> [Stage]Functoid {
	:transform{
		p: [Stage::Prev+]DefaultVariant #&,
		f: Stage::PrevFile+,
		s: Stage &,
		parent: [Stage]ScopeBase \
	} -> (:transform, p, f, s, parent);
}
::rlc::ast [Stage:TYPE] SpecialVariant -> [Stage]Functoid {
	Variant: function::SpecialVariant;

	:transform{
		p: [Stage::Prev+]SpecialVariant #&,
		f: Stage::PrevFile+,
		s: Stage &,
		parent: [Stage]ScopeBase \
	} -> (:transform, p, f, s, parent):
		Variant := p.Variant;
}
::rlc::ast [Stage:TYPE] Variant -> [Stage]Functoid {
	Name: Stage::Name+;

	:transform{
		p: [Stage::Prev+]Variant #&,
		f: Stage::PrevFile+,
		s: Stage &,
		parent: [Stage]ScopeBase \
	} -> (:transform, p, f, s, parent):
		Name := s.transform_name(p.Name, f);
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
		f: Stage::PrevFile+,
		s: Stage &,
		parent: [Stage]ScopeBase \
	>>> THIS - std::Dyn
	{
		TYPE SWITCH(p)
		{
		[Stage::Prev+]Converter:
			= :a.[Stage]Converter(:transform(
				<<[Stage::Prev+]Converter #&>>(p), f, s, parent));
		[Stage::Prev+]MemberFunction:
			= :a.[Stage]MemberFunction(:transform(
				<<[Stage::Prev+]MemberFunction #&>>(p), f, s, parent));
		[Stage::Prev+]Operator:
			= :a.[Stage]Operator(:transform(
				<<[Stage::Prev+]Operator #&>>(p), f, s, parent));
		}
	}
}

(// Type conversion operator. /)
::rlc::ast [Stage:TYPE] Converter -> [Stage]Abstractable, [Stage]Functoid
{
	:transform{
		p: [Stage::Prev+]Converter #&,
		f: Stage::PrevFile+,
		s: Stage &,
		parent: [Stage]ScopeBase \
	} -> (:transform, p), (:transform, p, f, s, parent);

	# type() [Stage]Type #\ INLINE := &*<<[Stage]ResolvedSig #\>>(THIS.Signature)->Return;

	// Make converters unique per type.
	# THIS<>(rhs: THIS#&) S1 := *type() <> *rhs.type();
}

::rlc::ast [Stage:TYPE] MemberFunction -> [Stage]Abstractable, [Stage]Function
{
	:transform{
		p: [Stage::Prev+]MemberFunction #&,
		f: Stage::PrevFile+,
		s: Stage &,
		parent: [Stage]ScopeBase \
	} -> (:transform, p), (:transform, p, f, s, parent);

	# THIS <> (rhs: THIS #&) S1 INLINE
		:= <[Stage]Function&>(THIS) <> <[Stage]Function&>(rhs);
}

/// Custom operator implementation.
::rlc::ast [Stage:TYPE] Operator -> [Stage]Abstractable, [Stage]Functoid
{
	Op: rlc::Operator;

	:transform{
		p: [Stage::Prev+]Operator #&,
		f: Stage::PrevFile+,
		s: Stage &,
		parent: [Stage]ScopeBase \
	} -> (:transform, p), (:transform, p, f, s, parent):
		Op := p.Op;

	# THIS <> (rhs: THIS #&) S1 := <S1>(Op) <> <S1>(rhs.Op);
}

::rlc::ast [Stage:TYPE] Factory -> [Stage]Member, [Stage]Functoid
{
	:transform{
		p: [Stage::Prev+]Factory #&,
		f: Stage::PrevFile+,
		s: Stage &,
		parent: [Stage]ScopeBase \
	} -> (:transform, p), (:transform, p, f, s, parent);
}